# Salesforce-NetSuite-Slack quote to cash integration

The quote-to-cash use case is often a sticking point for many organizations, especially aligning their CRM and ERP 
systems in particular. Today we will cover the NetSuite and Salesforce integration to implement this use case. When 
an opportunity in Salesforce  closes, that prospect now becomes a customer and customer record has to be then created 
within NetSuite which then ensures that the invoice and that billing actually takes place. That is, the quote that 
exists in Salesforce suddenly becomes an invoice within NetSuite. Finally we extend the case to send a notification 
to sales team through the Slack.

> This guide walks you through two workflows under this use case:
>1. Creating or updating corresponding account records between the ERP and CRM 
>2. Generating an invoice in your ERP once a quote is finalized
>3. Sending notification to sales team

## What you'll build

In this particular use case, following steps will be implemented under workflow 1

1. Once an opportunity is updated in Salesforce, we retrieve several select fields from that opportunity record via 
the triggered event.
2. Then we perform a conditional check here to check whether that stage has been ‘Closed Won’.  
3. If it’s ‘Closed Won’, we retrieve the account record in Salesforce that is associated with that closed deal in 
order to create and generate a new account record within NetSuite. 
4. When generating new records within NetSuite, you don't want to create duplicate records, so at this stage of the 
workflow we perform a search within NetSuite to check whether that account record already exists within NetSuite.
5. If that account does indeed exist, then we update that account with any new fields that may have been updated within 
Salesforce. 
6. If that record doesn't exist then we go ahead and create a net new account record within NetSuite, basically 
automating that process of aligning your ERP account records and your CRM records. 

Once the account is created, workflow 2 can be implemented as follows

1. Whenever a quote is updated within Salesforce, An event is triggers with specific quote details. 
2. Then we check if it's been approved and if it has been approved we create a corresponding invoice within NetSuite.

Later we can improve the workflow 2 to create a custom slack notification if invoices are above a certain price 
threshold.

1. Refer to the quote from that salesforce step and the total price of that quote and if it is greater than 1 million 
dollars, send a slack message to the sales team.
 
You can use Ballerina Salesforce event listener to get opportunity and quote events. ERP can be updated using 
Ballerina NetSuite connector and to send the notification, Ballerina Slack connector can be used.
