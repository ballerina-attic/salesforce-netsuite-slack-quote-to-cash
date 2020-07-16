import ballerina/log;
import ballerinax/netsuite;

function createNewCustomer(string customerId) returns @tainted netsuite:Customer|netsuite:Error {

    // Get the subsidiary, which the Customer record belongs to.
    string subsidiaryId = "1"; 
    netsuite:ReadableRecord|netsuite:Error retrieved = nsClient->get(subsidiaryId, netsuite:Subsidiary);
    if retrieved is netsuite:Error {
        return netsuite:Error("Failed to retrieve Subsidiary", retrieved);
    }
    netsuite:Subsidiary subsidiary = <netsuite:Subsidiary> retrieved;

    netsuite:Customer customer = {
        entityId: customerId,
        companyName: customerId,
        subsidiary: subsidiary
    };

    // Create the Customer record in NetSuite.
    string|netsuite:Error created = nsClient->create(<@untainted> customer);
    if created is netsuite:Error {
        return netsuite:Error("Failed to create Customer", created);
    }
    string id = <string> created;
    log:printInfo("New customer is created: customer id = " + id);
    
    return retriveExistingCustomer(<@untainted> id);
}


function retriveExistingCustomer(string id) returns @tainted netsuite:Customer|netsuite:Error {
    netsuite:ReadableRecord|netsuite:Error retrieved = nsClient->get(id, netsuite:Customer);
    if retrieved is netsuite:Error {
        return netsuite:Error("Failed to retrieve Customer", retrieved);
    }
    return  <netsuite:Customer> retrieved;
}


function getNonInventoryItem() returns @tainted netsuite:NonInventoryItem|netsuite:Error {
    var lists = nsClient->search(netsuite:NonInventoryItem);
    if (lists is netsuite:Error) {
        return netsuite:Error("Failed to search for NonInventoryItem", lists);
    }

    var [ids, hasMore] = <[string[], boolean]> lists;
    if (ids.length() == 0) {
        return netsuite:Error("No search results for NonInventoryItem");
    }

    netsuite:ReadableRecord|netsuite:Error getResult = nsClient->get(<@untainted> ids[0], netsuite:NonInventoryItem);
    if (getResult is netsuite:Error) {
        return netsuite:Error("Failed to retrieve NonInventoryItem", getResult);
    }
    return <netsuite:NonInventoryItem> getResult;
}
