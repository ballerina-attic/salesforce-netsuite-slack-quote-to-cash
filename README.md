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

The following are the sections available in this guide.

- [What you'll build](#what-youll-build)
- [Prerequisites](#prerequisites)
- [Execute the integration](#execute-the-integration)

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

## Prerequisites

- [Ballerina Distribution](https://ballerina.io/learn/getting-started/)
- A Text Editor or an IDE 
> **Tip**: For a better development experience, install one of the following Ballerina IDE plugins:  
[VSCode](https://marketplace.visualstudio.com/items?itemName=ballerina.ballerina), 
[IntelliJ IDEA](https://plugins.jetbrains.com/plugin/9520-ballerina)
- [Salesforce Connector](https://github.com/ballerina-platform/module-ballerinax-sfdc), 
[NetSuite Connector](https://github.com/ballerina-platform/module-ballerinax-netsuite) and 
[Slack Connector](https://github.com/ballerina-platform/module-ballerinax-slack) will be downloaded from 
`Ballerina Central` when running the Ballerina file.

### Before you begin

Let's first see how to add the Salesforce, NetSuite and Slack configurations for the application.

#### Setup Salesforce configurations
Create a Salesforce account and create a connected app by visiting [Salesforce](https://www.salesforce.com). 
Obtain the following parameters:

* Base URL (Endpoint)
* Client Id
* Client Secret
* Access Token
* Refresh Token
* Refresh URL

For more information on obtaining OAuth2 credentials, visit 
[Salesforce help documentation](https://help.salesforce.com/articleView?id=remoteaccess_authenticate_overview.htm) 
or follow the 
[Setup tutorial](https://medium.com/@bpmmendis94/obtain-access-refresh-tokens-from-salesforce-rest-api-a324fe4ccd9b).

Also, keep a note of your Salesforce username, password and the security token that will be needed for initializing the listener. 

For more information on the secret token, please visit [Reset Your Security Token](https://help.salesforce.com/articleView?id=user_security_token.htm&type=5).

#### Create push topic in Salesforce developer console

The Salesforce trigger requires topics to be created for each event. We need to configure two topics as we listen on 
both Opportunity and Quote entities.

1. From the Salesforce UI, select developer console. Go to debug > Open Execute Anonymous Window. 
2. Paste following apex code to create 'OpportunityUpdate' topic
```apex
PushTopic pushTopic = new PushTopic();
pushTopic.Name = 'OpportunityUpdate';
pushTopic.Query = 'SELECT Id, Name, AccountId, StageName, Amount FROM Opportunity';
pushTopic.ApiVersion = 48.0;
pushTopic.NotifyForOperationUpdate = true;
pushTopic.NotifyForFields = 'Referenced';
insert pushTopic;
```
3. Execute another window and paste following to create 'QuoteUpdate' topic
```apex
PushTopic pushTopic = new PushTopic();
pushTopic.Name = 'QuoteUpdate';
pushTopic.Query = 'SELECT Id, Name, AccountId, OpportunityId, Status,GrandTotal  FROM Quote';
pushTopic.ApiVersion = 48.0;
pushTopic.NotifyForOperationUpdate = true;
pushTopic.NotifyForFields = 'Referenced';
insert pushTopic;
```
4. Once the creation is done, specify the topic name in each event listener service config.

#### Setup NetSuite configurations
Create a [NetSuite](https://www.netsuite.com/portal/home.shtml) account and integration record to obtain the following 
parameters:

* Client ID
* Client Secret
* Access Token
* Refresh Token
* Refresh Token URL

For more information on obtaining the above parameters, follow the 
[setup tutorial](https://medium.com/@chamilelle/setup-rest-web-service-and-oauth-2-0-in-your-netsuite-account-c4243240bc3f).

#### Setup Slack configurations
Create a new [Slack](https://api.slack.com/apps?new_granular_bot_app=1) app and obtain the access token. For more 
information on obtaining the token, follow the 
[documentation](https://github.com/ballerina-platform/module-ballerinax-slack/blob/master/src/slack/Module.md). 
Make sure you set `chat:write` and `channel:read` as scopes in your app. 

Once you obtained all configurations, Replace "" in the `ballerina.conf` file with your data.

##### ballerina.conf
```
SF_EP_URL="https://<instance-id>.salesforce.com"
SF_REDIRECT_URL="https://login.salesforce.com/"
SF_ACCESS_TOKEN="<ACCESS_TOKEN>"
SF_CLIENT_ID="<CLIENT_ID>"
SF_CLIENT_SECRET="<CLIENT_SECRET>"
SF_REFRESH_TOKEN="<REFRESH_TOKEN>"
SF_REFRESH_URL="https://login.salesforce.com/services/oauth2/token"

SF_USERNAME="<SF_USERNAME>"
SF_PASSWORD="<SF_PASSWORD + SECURITY_TOKEN>"

NS_BASE_URL="https://<instance-id>.suitetalk.api.netsuite.com"
NS_ACCESS_TOKEN="<ACCESS_TOKEN>"
NS_REFRESH_URL="https://<instance-id>.suitetalk.api.netsuite.com/services/rest/auth/oauth2/v1/token"
NS_REFRESH_TOKEN="<REFRESH_TOKEN>"
NS_CLIENT_ID="<CLIENT_ID>"
NS_CLIENT_SECRET="<CLIENT_SECRET>"

SLACK_ACCESS_TOKEN="<ACCESS_TOKEN>"
```


## Execute the integration

Go to root of the project and run following cmd.
`$ ballerina run workflow`

Successful listener startup will print following in the console.
```
>>>>
[2020-06-25 15:57:07.114] Success:[/meta/handshake]
{ext={replay=true, payload.format=true}, minimumVersion=1.0, clientId=6zp60zass9ub6xxpjc19g9e7mzj, supportedConnectionTypes=[Ljava.lang.Object;@17744dc, channel=/meta/handshake, id=1, version=1.0, successful=true}
<<<<
Subscribed: Subscription [/topic/OpportunityUpdate:-2]
```
To trigger the opportunity event listener, As the first step, you need to create an sales account called `TestWorkFlow` 
in Salesforce. Then create an opportunity for the account and set its stage as closed won. As soon as you change the 
stage event listener will get triggered with following output.
```
<<<<
Opportunity Stage : Closed Won
Account ID : 0012w00000DuVnyAAF
Account Name : TestWorkFlow
New customer is created: customer id = 41537
>>>>
```

To execute the second workflow, quote update event should be triggered. So go to the opportunity and create a quote. 
The change the stage to approved state. As soon as you change the stage, quote event listener will get triggered with 
following output.
```
2020-06-25 19:54:31,153 INFO  [chamil/workflow] - Quote Status : Approved 
2020-06-25 19:54:31,539 INFO  [chamil/workflow] - Account Name : TestWorkFlow 
2020-06-25 19:54:32,765 INFO  [chamil/workflow] - Retrieved customer id : 41537 
2020-06-25 19:54:40,178 INFO  [chamil/workflow] - The invoice has created: id = 519194 
```

If the quote exceeds the expected threshold, the slack notification will be sent with the following output.

```
2020-06-25 19:55:40,178 INFO  [chamil/workflow] - Message posted to channel 1594193873.002600 
```
