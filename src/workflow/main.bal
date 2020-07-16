import ballerina/io;
import ballerina/lang.'float;
import ballerina/log;
import ballerinax/netsuite;
import ballerinax/slack;
import ballerinax/sfdc;

netsuite:Client nsClient = new(nsConfig);
sfdc:BaseClient baseClient = new(sfConfig);
slack:Client slackClient = new(slackConfig);

listener sfdc:Listener eventListener = new (listenerConfig);

@sfdc:ServiceConfig {
    topic:"/topic/OpportunityUpdate"
}
service workflowOne on eventListener {
    resource function onEvent(json op) {  
        //convert json string to json
        io:StringReader sr = new(op.toJsonString());
        json|error opportunity = sr.readJson();
        if (opportunity is json) {
            log:printInfo("Opportunity Stage : " + opportunity.sobject.StageName.toString());
            //check if opportunity is closed won
            if (opportunity.sobject.StageName == "Closed Won") {
                //get the account id from the opportunity
                string accountId = opportunity.sobject.AccountId.toString();
                log:printInfo("Account ID : " + accountId);
                //create sobject client
                sfdc:SObjectClient sobjectClient = baseClient->getSobjectClient();
                //get account
                json|sfdc:Error account = sobjectClient->getAccountById(accountId);
                if (account is json) {
                    //extract required fields from the account record
                    string accountName = account.Name.toString();
                    log:printInfo("Account Name : " + accountName);
                    //NetSuite logic follows...
                    error|() err = updateNetSuiteCustomer(<@untainted> accountName);
                    if (err is error) {
                        log:printError("Failed to update customer record in NetSuite", err);
                    }
                }
            }
        }
    }
}

@sfdc:ServiceConfig {
    topic:"/topic/QuoteUpdate"
}
service workflowTwo on eventListener {
    resource function onEvent(json qu) {  
        //convert json string to json      
        io:StringReader sr = new(qu.toJsonString());
        json|error quote = sr.readJson();
        if (quote is json) {
            log:printInfo("Quote Status : " + quote.sobject.Status.toString());
            //check if status is approved
            if (quote.sobject.Status == "Approved"){

                //extract GrandTotal
                var grandTotal = 'float:fromString(quote.sobject.GrandTotal.toString());
                if grandTotal is sfdc:Error {
                    log:printError("Invalid data type" + grandTotal.message());
                    return;
                }
                float invoiceAmount = <float> grandTotal;

                //extract required fields
                string opportunityId = quote.sobject.OpportunityId.toString();
                
                //create sobject client
                sfdc:SObjectClient sobjectClient = baseClient->getSobjectClient();
                
                //get opportunity
                json|sfdc:Error opportunity = sobjectClient->getOpportunityById(opportunityId);
                if (opportunity is json) {
                    //get the account id from the opportunity
                    string accountId = opportunity.AccountId.toString();
                    json|sfdc:Error account = sobjectClient->getAccountById(accountId);
                    if (account is json) {
                        //extract required fields from the account record
                        string accountName = account.Name.toString();
                        log:printInfo("Account Name : " + accountName);

                        // NetSuite logic follows...
                        error? err = generateNetSuiteInvoice(invoiceAmount, <@untainted> accountName);
                        if (err is error) {
                            log:printError("Failed to generate Invoice in NetSuite", err);
                            return;
                        }

                        // Slack notification...
                        if (invoiceAmount >= 1000000.00) {
                            sendSlackNotification(invoiceAmount, accountName);
                        }
                    }
                }
            }
        }
    }
}

function updateNetSuiteCustomer(string customerId) returns @tainted error? {

    netsuite:Customer? customer = ();

    // Search for existing customer record under customerId (Step 4).
    [string[], boolean]|netsuite:Error result = nsClient->search(netsuite:Customer, "entityId IS " + customerId);
    if result is netsuite:Error {
        log:printInfo(result.message());
        customer = check createNewCustomer(customerId);
    } else {
        var [idArr, hasMore] = result;

        if (idArr.length() == 0) {
            // Create new customer record (step 6).
            customer = check createNewCustomer(customerId);
        } else {
            customer = check retriveExistingCustomer(<@untainted> idArr[0]);
            log:printInfo("Existing customer is retrieved: customer id = " + idArr[0]);
            // Update the existing customer with the `companyName` (Step 5).
            json cName = { companyName: "ballerinalang" };
            string|netsuite:Error updated = nsClient->update(<@untainted netsuite:Customer> customer, cName);
            if updated is netsuite:Error {
                log:printInfo(updated.message());
                return netsuite:Error("Customer Update operation failed", updated);
            }

        }
    }
}

function generateNetSuiteInvoice(float grandTotal, string accountName) returns @tainted error? {
    netsuite:Customer? customer = ();

    // Search for respective customer via accountName.
    [string[], boolean]|netsuite:Error result = nsClient->search(netsuite:Customer, "entityId IS " + accountName);
    if result is netsuite:Error {
        return netsuite:Error("Customer search operation failed", result);
    } else {
        var [idArr, hasMore] = result;

        if (idArr.length() == 0) {
            return netsuite:Error("No such Customer record found");
        } else {
            customer = check retriveExistingCustomer(<@untainted> idArr[0]);
            log:printInfo("Retrieved customer id : " + idArr[0]);
        }
    }

    // Assume that the quote is created for serviceItem
    netsuite:NonInventoryItem nonInventoryItem = check getNonInventoryItem();

    netsuite:ItemElement serviceItem = {
        amount: grandTotal,
        item: nonInventoryItem,
        itemSubType: "Sale",
        itemType: "NonInvtPart"
    };

    // Get the Classification(POD), which the invoice belongs to.
    string classANZId = "88"; 
    netsuite:ReadableRecord|netsuite:Error retrieved = nsClient->get(classANZId, netsuite:Classification);
    if retrieved is netsuite:Error {
        return netsuite:Error("Classification retrieval failed", retrieved);
    }
    netsuite:Classification class = <netsuite:Classification> retrieved;

    netsuite:Invoice invoice = {
        entity: <netsuite:Customer> customer,
        class: class,
        item: {
            items: [serviceItem],
            totalResults: 1
        },
        memo: "workflow 2"
    };

    // Create the Invoice record in NetSuite.
    string|netsuite:Error created = nsClient->create(<@untainted> invoice);
    if created is netsuite:Error {
        return netsuite:Error("Invoice creation failed", created);
    }
    string id = <string> created;
    log:printInfo("The invoice has created: id = " + id);
    return;
}

function sendSlackNotification(float invoiceAmount, string accountName) {
    slack:ChatClient chatClient = slackClient.getChatClient();
    slack:Message messageParams = {
        channelName: "announcements",
        text: "New invoice has been creared for " + invoiceAmount.toString() +
                " under account : " + accountName
    };

    string|error response = chatClient->postMessage(messageParams);
    if (response is string) {
        log:printInfo("Message posted to channel " + response);
    } else {
        log:printError("Failed to sent notification", response);
    }
}
