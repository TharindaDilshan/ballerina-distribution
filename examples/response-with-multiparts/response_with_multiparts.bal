import ballerina/http;
import ballerina/io;
import ballerina/log;
import ballerina/mime;

// Creates an endpoint for the client.
http:Client clientEP = check new ("http://localhost:9092");

// Creates a listener for the service.
listener http:Listener multipartEP = new (9090);

service /multiparts on new http:Listener(9092) {

    resource function get encode_out_response(http:Caller caller,
                                        http:Request request) {
        // Creates an enclosing entity to hold the child parts.
        mime:Entity parentPart = new;

        // Creates a child part with the JSON content.
        mime:Entity childPart1 = new;
        childPart1.setJson({"name": "wso2"});
        // Creates another child part with a file.
        mime:Entity childPart2 = new;
        // This file path is relative to where the Ballerina is running.
        //If your file is located outside, please give the
        //absolute file path instead.
        childPart2.setFileAsEntityBody("./files/test.xml",
            contentType = mime:TEXT_XML);
        // Creates an array to hold the child parts.
        mime:Entity[] childParts = [childPart1, childPart2];
        // [Sets the child parts to the parent part](https://ballerina.io/swan-lake/learn/api-docs/ballerina/#/ballerina/mime/latest/mime/classes/Entity#setBodyParts).
        parentPart.setBodyParts(childParts,
            contentType = mime:MULTIPART_MIXED);
        // Creates an array to hold the parent part and set it to the response.
        mime:Entity[] immediatePartsToResponse = [parentPart];
        http:Response outResponse = new;
        outResponse.setBodyParts(immediatePartsToResponse,
            contentType = mime:MULTIPART_FORM_DATA);
        var result = caller->respond(outResponse);
        if (result is error) {
            log:printError("Error in responding ", err = result);
        }
    }
}

// Binds the listener to the service.
service /multiparts on multipartEP {

    // This resource accepts multipart responses.
    resource function get decode_in_response(http:Caller caller,
                                        http:Request request) {
        http:Response inResponse = new;
        var returnResult = clientEP->get("/multiparts/encode_out_response");
        http:Response res = new;
        if (returnResult is http:Response) {
            // [Extracts the body parts from the response](https://ballerina.io/swan-lake/learn/api-docs/ballerina/#/ballerina/http/latest/http/classes/Response#getBodyParts).
            var parentParts = returnResult.getBodyParts();
            if (parentParts is mime:Entity[]) {
                //Loops through body parts.
                foreach var parentPart in parentParts {
                    handleNestedParts(parentPart);
                }
                res.setPayload("Body Parts Received!");
            }
        } else {
            res.statusCode = 500;
            res.setPayload("Connection error");
        }
        var result = caller->respond(res);
        if (result is error) {
            log:printError("Error in responding ", err = result);
        }
    }
}

// Gets the child parts that are nested within the parent.
function handleNestedParts(mime:Entity parentPart) {
    string contentTypeOfParent = parentPart.getContentType();
    if (contentTypeOfParent.startsWith("multipart/")) {
        var childParts = parentPart.getBodyParts();
        if (childParts is mime:Entity[]) {
            log:print("Nested Parts Detected!");
            foreach var childPart in childParts {
                handleContent(childPart);
            }
        } else {
            log:printError("Error retrieving child parts! " +
                            childParts.message());
        }
    }
}

//The content logic that handles the body parts
//vary based on your requirement.
function handleContent(mime:Entity bodyPart) {
    string baseType = getBaseType(bodyPart.getContentType());
    if (mime:APPLICATION_XML == baseType || mime:TEXT_XML == baseType) {
        // [Extracts `xml` data]((https://ballerina.io/swan-lake/learn/api-docs/ballerina/#/ballerina/mime/latest/mime/classes/Entity#getXml) from the body part.
        var payload = bodyPart.getXml();
        if (payload is xml) {
            string strValue = io:sprintf("%s", payload);
             log:print("XML data: " + strValue);
        } else {
             log:printError("Error in parsing XML data", err = payload);
        }
    } else if (mime:APPLICATION_JSON == baseType) {
        // [Extracts `json` data](https://ballerina.io/swan-lake/learn/api-docs/ballerina/#/ballerina/mime/latest/mime/classes/Entity#getJson) from the body part.
        var payload = bodyPart.getJson();
        if (payload is json) {
            log:print("JSON data: " + payload.toJsonString());
        } else {
             log:printError("Error in parsing JSON data", err = payload);
        }
    } else if (mime:TEXT_PLAIN == baseType) {
        // [Extracts text data](https://ballerina.io/swan-lake/learn/api-docs/ballerina/#/ballerina/mime/latest/mime/classes/Entity#getText) from the body part.
        var payload = bodyPart.getText();
        if (payload is string) {
            log:print("Text data: " + payload);
        } else {
            log:printError("Error in parsing text data", err = payload);
        }
    }
}

//Gets the base type from a given content type.
function getBaseType(string contentType) returns string {
    var result = mime:getMediaType(contentType);
    if (result is mime:MediaType) {
        return result.getBaseType();
    } else {
        panic result;
    }
}

// Copies the content from the source channel to the destination channel.
function copy(io:ReadableByteChannel src, io:WritableByteChannel dst)
                returns error? {
    while (true) {
        //Operation attempts to read a maximum of 1000 bytes.
        byte[]|io:Error result = src.read(1000);
        if (result is io:EofError) {
            break;
        } else if (result is error) {
            return <@untainted>result;
        } else {
            //Writes the given content into the channel.
            int i = 0;
            while (i < result.length()) {
                var result2 = dst.write(result, i);
                if (result2 is error) {
                    return result2;
                } else {
                    i = i + result2;
                }
            }
        }
    }
    return;
}

//Closes the byte channel.
function close(io:ReadableByteChannel|io:WritableByteChannel ch) {
    object {
        public function close() returns error?;
    } channelResult = ch;
    var cr = channelResult.close();
    if (cr is error) {
        log:printError("Error occurred while closing the channel: ", err = cr);
    }
}
