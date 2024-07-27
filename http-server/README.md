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


## Extract URL path

In this stage, your server will extract the URL path from an HTTP request, and respond with either a `200` or `404`, depending on the path.

### HTTP request

An HTTP request is made up of three parts, each separated by a [CRLF](https://developer.mozilla.org/en-US/docs/Glossary/CRLF) (`\r\n`):

1. Request line.
1. Zero or more headers, each ending with a CRLF.
1. Optional request body.

Here's an example of an HTTP request:
```
GET /index.html HTTP/1.1\r\nHost: localhost:4221\r\nUser-Agent: curl/7.64.1\r\nAccept: */*\r\n\r\n
```

Here's a breakdown of the request:
```
// Request line
GET                          // HTTP method
/index.html                  // Request target
HTTP/1.1                     // HTTP version
\r\n                         // CRLF that marks the end of the request line
// Headers
Host: localhost:4221\r\n     // Header that specifies the server's host and port
User-Agent: curl/7.64.1\r\n  // Header that describes the client's user agent
Accept: */*\r\n              // Header that specifies which media types the client can accept
\r\n                         // CRLF that marks the end of the headers
// Request body (empty)
```

The "request target" specifies the URL path for this request.  In this example, the URL path is `/index.html`.

Note that each header ends in a CRLF, and the entire header section also ends in a CRLF.

### Tests

The tester will execute your program like this:
```
$ dune exec ./http_server.exe
```

The tester will then send two HTTP requests to your server.

First, the tester will send a `GET` request, with a random string as the path:
```
$ curl -v http://localhost:4221/abcdefg
```

Your server must respond to this request with a `404` response:
```
HTTP/1.1 404 Not Found\r\n\r\n
```

Then, the tester will send a `GET` request, with the path `/`:
```
$ curl -v http://localhost:4221
```

Your server must respond to this request with a `200` response:
```
HTTP/1.1 200 OK\r\n\r\n
```

### Notes

- You can ignore the headers for now.  You'll learn about parsing headers in a later stage.
- In this stage, the request target is written as a URL path.  But the request target actually has [four possible formats](https://datatracker.ietf.org/doc/html/rfc9112#section-3.2).  The URL path format is called the "origin form", and it's the most commonly used format.  The other formats are used for more niche scenarios, like sending a request through a proxy.
- For more information about HTTP requests, see the [MDN Web Docs on HTTP requests](https://developer.mozilla.org/en-US/docs/Web/HTTP/Messages#http_requests) or the [HTTP/1.1 specification](https://datatracker.ietf.org/doc/html/rfc9112#name-message).


## Response with body

In this stage, you'll implement the `/echo/{str}` endpoint, which accepts a string and returns it in the response body.

### Response body

A response body is used to return content to the client.  This content may be an entire web page, a file, a string, or anything else that can be represented with bytes.

Your `/echo/{str}` endpoint must return a `200` response, with the response body set to given string, and with a `Content-Type` and `Content-Length` header.

Here's an example of an `/echo/{str}` request:
```
GET /echo/abc HTTP/1.1\r\nHost: localhost:4221\r\nUser-Agent: curl/7.64.1\r\nAccept: */*\r\n\r\n
```

And here's the expected response:
```
HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 3\r\n\r\nabc
```

Here's a breakdown of the response:
```
// Status line
HTTP/1.1 200 OK
\r\n                          // CRLF that marks the end of the status line
// Headers
Content-Type: text/plain\r\n  // Header that specifies the format of the response body
Content-Length: 3\r\n         // Header that specifies the size of the response body, in bytes
\r\n                          // CRLF that marks the end of the headers
// Response body
abc                           // The string from the request
```

The two headers are required for the client to be able to parse the response body.  Note that each header ends in a CRLF, and the entire header section also ends in a CRLF.

### Tests

The tester will execute your program like this:
```
$ dune exec ./http_server.exe
```

The tester will then send a `GET` request to the `/echo/{str}` endpoint on your server, with some random string.
```
$ curl -v http://localhost:4221/echo/abc
```

Your server must respond with a `200` response that contains the following parts:

- `Content-Type` header set to `text/plain`.
- `Content-Length` header set to the length of the given string.
- Response body set to the given string.

```
HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 3\r\n\r\nabc
```

### Notes

- For more information about HTTP responses, see the [MDN Web Docs on HTTP responses](https://developer.mozilla.org/en-US/docs/Web/HTTP/Messages#http_responses) or the [HTTP/1.1 specification](https://datatracker.ietf.org/doc/html/rfc9112#name-message).


## Read header

In this stage, you'll implement the `/user-agent` endpoint, which reads the `User-Agent` request header and returns it in the response body.

### The `User-Agent` header

The [`User-Agent`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/User-Agent) header describes the client's user agent.

Your `/user-agent` endpoint must read the `User-Agent` header, and return it in your response body.  Here's an example of a `/user-agent` request:
```
// Request line
GET
/user-agent
HTTP/1.1
\r\n
// Headers
Host: localhost:4221\r\n
User-Agent: foobar/1.2.3\r\n  // Read this value
Accept: */*\r\n
\r\n
// Request body (empty)
```

Here is the expected response:
```
// Status line
HTTP/1.1 200 OK               // Status code must be 200
\r\n
// Headers
Content-Type: text/plain\r\n
Content-Length: 12\r\n
\r\n
// Response body
foobar/1.2.3                  // The value of `User-Agent`
```

### Tests

The tester will execute your program like this:
```
$ dune exec ./http_server.exe
```

The tester will then send a `GET` request to the `/user-agent` endpoint on your server.  The request will have a `User-Agent` header.
```
$ curl -v --header "User-Agent: foobar/1.2.3" http://localhost:4221/user-agent
```

Your server must respond with a `200` response that contains the following parts:

- `Content-Type` header set to `text/plain`.
- `Content-Length` header set to the length of the `User-Agent` value.
- Message body set to the `User-Agent` value.

```
HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 12\r\n\r\nfoobar/1.2.3
```

### Notes

- Header names are [case-insensitive](https://datatracker.ietf.org/doc/html/rfc9112#name-field-syntax).
