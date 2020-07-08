import ballerina/config;
import ballerinax/netsuite;
import ballerinax/slack;
import thishani/sfdc;

netsuite:Configuration nsConfig = {
    baseUrl: config:getAsString("NS_BASE_URL"),
    oauth2Config: {
        accessToken: config:getAsString("NS_ACCESS_TOKEN"),
        refreshConfig: {
            refreshUrl: config:getAsString("NS_REFRESH_URL"),
            refreshToken: config:getAsString("NS_REFRESH_TOKEN"),
            clientId: config:getAsString("NS_CLIENT_ID"),
            clientSecret: config:getAsString("NS_CLIENT_SECRET")
        }
    }
};

sfdc:SalesforceConfiguration sfConfig = {
    baseUrl: config:getAsString("SF_EP_URL"),
    clientConfig: {
        accessToken: config:getAsString("SF_ACCESS_TOKEN"),
        refreshConfig: {
            clientId: config:getAsString("SF_CLIENT_ID"),
            clientSecret: config:getAsString("SF_CLIENT_SECRET"),
            refreshToken: config:getAsString("SF_REFRESH_TOKEN"),
            refreshUrl: config:getAsString("SF_REFRESH_URL")
        }
    }
};

sfdc:ListenerConfiguration opportunityListenerConfig = {
    apiUrl: config:getAsString("SF_EP_URL"),
    token: config:getAsString("BEARER_TOKEN"),
    topic: config:getAsString("OPPORTUNITY_UPDATE_TOPIC")
};

sfdc:ListenerConfiguration quoteListenerConfig = {
    apiUrl: config:getAsString("SF_EP_URL"),
    token: config:getAsString("BEARER_TOKEN"),
    topic: config:getAsString("QUOTE_UPDATE_TOPIC")
};

slack:Configuration slackConfig = {
    oauth2Config: {
        accessToken: config:getAsString("SLACK_ACCESS_TOKEN")
    }
};
