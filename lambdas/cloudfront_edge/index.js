"use strict";
const config = require('./config.json');

exports.handler = (event, context, callback) => {
  try {
    const { request } = event.Records[0].cf;

    ///////////////////////////////////////////
    // [Step] Check for CORS requests
    if (request.method === "OPTIONS") {
      return {
        status: 404,
        statusDescription: "Not Found",
        headers: [],
      };
    }

    ///////////////////////////////////////////
    // [Step] Check for / path and get index.html file
    if (/\/$/.test(request.uri)) {
      request.uri += "index.html";
    }

    ///////////////////////////////////////////
    // [Step] Map to s3 bucket path
    let domain = request.headers.host[0].value;
    let matches = domain.match(/([^.]+)(?:\.[^.]+){2}$/);
    let path = matches?.[1] ?? null;

    // Return 400 if error
    if (path === null) {
      return {
        status: 400,
        statusDescription: "Bad Request",
        headers: [],
      };
    }

    ///////////////////////////////////////////
    // [Step] Update request to include s3 branch folder
    request.uri = "/" + path + request.uri;

    ///////////////////////////////////////////
    // [Step] Replace host with s3 bucket
    const rootDomain = request.headers.host[0].value.replace(/^[^.]+\./, '');

    if( !config.domainToS3.hasOwnProperty(rootDomain) ) {
      return {
        status: 404,
        statusDescription: "Not Found",
        headers: [],
      };
    }
    
    request.headers.host[0].value = config.domainToS3[rootDomain];
    
    ///////////////////////////////////////////
    // [Step] Return callback with updated request
    return callback(null, request);
    
  } catch (error) {
    console.error("==============================");
    console.error("ERROR");
    console.error(error);
  }
};
