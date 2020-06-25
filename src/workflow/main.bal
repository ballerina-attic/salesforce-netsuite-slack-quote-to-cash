import ballerina/io;
import ballerinax/netsuite;
import thishani/sfdc;

netsuite:Client nsClient = new(nsConfig);
sfdc:BaseClient baseClient = new(sfConfig);

listener sfdc:EventListener opportunityUpdateListener = new(opportunityListenerConfig);
// listener sfdc:EventListener quoteUpdateListener = new(quoteListenerConfig);

service workflowOne on opportunityUpdateListener {
    resource function onEvent(json op) {  
        //convert json string to json
        io:StringReader sr = new(op.toJsonString());
        json|error opportunity = sr.readJson();
        if (opportunity is json) {
            io:println("Opportunity Stage : ", opportunity.sobject.StageName);
            //check if opportunity is closed won
            if (opportunity.sobject.StageName == "Closed Won") {
                //get the account id from the opportunity
                string accountId = opportunity.sobject.AccountId.toString();
                io:println("Account ID : ", accountId);
                //create sobject client
                sfdc:SObjectClient sobjectClient = baseClient->getSobjectClient();
                //get account
                json|sfdc:Error account = sobjectClient->getAccountById(accountId);
                if (account is json) {
                    //extract required fields from the account record
                    string accountName = account.Name.toString();
                    io:println("Account Name : ", accountName);
                    //Netsuite logic follows...
                    error? err = updateNetSuiteCustomer(<@untainted> accountName);
                    if (err is error) {
                        io:println("Failed to update customer account", err);
                    }
                }
            }
        }
    }
}

//TODO uncomment it once the quote-product problem is resolved
// service workflowTwo on quoteUpdateListener {
//     resource function onEvent(json qu) {  
//         //convert json string to json      
//         io:StringReader sr = new(qu.toJsonString());
//         json|error quote = sr.readJson();
//         if (quote is json) {
//             io:println("Quote Status : ", quote.sobject.Status);
//             //check if status is approved
//             if (quote.sobject.Status == "Approved"){
//                 //extract required fields
//                 string opportunityId = quote.sobject.OpportunityId.toString();
//                 io:println("Opportunity ID : ", opportunityId);

//                 //Netsuite logic follows...
//                 error? err = generateNetSuiteInvoice(opportunityId);
//                 if (err is error) {
//                     io:println("Failed to update customer account", err);
//                 }
//             }
//         }
//     }
// }

function updateNetSuiteCustomer(string customerId) returns @tainted error? {

    netsuite:Customer? customer = ();

    // Search for existing customer record under customerId (Step 4).
    [string[], boolean]|netsuite:Error result = nsClient->search(netsuite:Customer, "entityId IS " + customerId);
    if result is netsuite:Error {
        io:println(result.message());
        customer = check createNewCustomer(customerId);
    } else {
        var [idArr, hasMore] = result;

        if (idArr.length() == 0) {
            // Create new customer record (step 6).
            customer = check createNewCustomer(customerId);
        } else {
            customer = check retriveExistingCustomer(<@untainted> idArr[0]);
            io:println("Existing customer is retrieved: customer id = " + idArr[0]);
            // Update the existing customer with the `companyName` (Step 5).
            json cName = { companyName: "ballerinalang" };
            string|netsuite:Error updated = nsClient->update(<@untainted netsuite:Customer> customer, cName);
            if updated is netsuite:Error {
                io:println(updated.message());
                return netsuite:Error("Failed to update Customer", updated);
            }

        }
    }
}

function generateNetSuiteInvoice(string customerId) returns @tainted error? {
    netsuite:Customer? customer = ();
    // The quote should contain aleast 1 item. Until the salesforce logic is completed, a random item is used
    netsuite:NonInventoryItem nonInventoryItem = check getARandomItem();

    netsuite:ItemElement serviceItem = {
        amount: 39000.0,
        item: nonInventoryItem,
        itemSubType: "Sale",
        itemType: "NonInvtPart"
    };

    // Get the classification(POD), which the invoice belongs to.
    string classANZId = "88"; 
    netsuite:ReadableRecord|netsuite:Error retrieved = nsClient->get(classANZId, netsuite:Classification);
    if retrieved is netsuite:Error {
        io:println(retrieved.message());
        return netsuite:Error("Failed to retrieve Classification", retrieved);
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
        io:println(created.message());
        return netsuite:Error("Failed to create Invoice", created);
    }
    string id = <string> created;
    io:println("The invoice has created: id = " + id);
    return;
}
