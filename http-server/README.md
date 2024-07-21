# [Build your own HTTP server](https://app.codecrafters.io/courses/http-server/introduction)

## Introduction

Welcome to the Build your own HTTP server challenge!

HTTP is the protocol that powers the web.  In this challenge, you'll build a HTTP server that's capable of handling simple GET/POST requests, serving files and handling multiple concurrent connections.

Along the way, we'll learn about TCP connections, HTTP headers, HTTP verbs, handling multiple connections and more.


## Bind to a port

In this stage, you'll create a TCP server that listens on port 4221.

[TCP](https://www.cloudflare.com/en-ca/learning/ddos/glossary/tcp-ip/) is the underlying protocol used by HTTP servers.

### Tests

The tester will execute your program like this:
```
$ dune exec ./http_server.exe
```

Then, the tester will try to connect to your server on port 4221.  The connection must succeed for you to pass this stage.


## Respond with 200

In this stage, your server will respond to an HTTP request with a `200` response.

### HTTP response

An HTTP response is made up of three parts, each separated by a [CRLF](https://developer.mozilla.org/en-US/docs/Glossary/CRLF) (`\r\n`):

1. Status line.
1. Zero or more headers, each ending with a CRLF.
1. Optional response body.

In this stage, your server's response will only contain a status line.  Here's the response your server must send:
```
HTTP/1.1 200 OK\r\n\r\n
```

Here's a breakdown of the response:
```
// Status line
HTTP/1.1  // HTTP version
200       // Status code
OK        // Optional reason phrase
\r\n      // CRLF that marks the end of the status line
// Headers (empty)
\r\n      // CRLF that marks the end of the headers
// Response body (empty)
```

### Tests

The tester will execute your program like this:
```
$ dune exec ./http_server.exe
```

The tester will then send an HTTP `GET` request to your server:
```
$ curl -v http://localhost:4221
```

Your server must respond to the request with the following response:
```
HTTP/1.1 200 OK\r\n\r\n
```

### Notes

- You can ignore the contents of the request.  We'll cover parsing requests in later stages.
- For more information about HTTP responses, see the [MDN Web Docs on HTTP responses](https://developer.mozilla.org/en-US/docs/Web/HTTP/Messages#http_responses) or the [HTTP/1.1 specification](https://datatracker.ietf.org/doc/html/rfc9112#name-message).
- This challenge uses HTTP/1.1.
