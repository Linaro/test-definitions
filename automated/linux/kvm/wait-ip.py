#!/usr/bin/python
# Wait for a HTTP post and echo the IP of the first visitor

from BaseHTTPServer import BaseHTTPRequestHandler, HTTPServer

class MyHandler(BaseHTTPRequestHandler):
    def returnIP(self):
        self.send_response(200)
        self.end_headers()
        print self.client_address[0]
        return

    def log_message(self, format, *args):
        return

    def do_POST(self):
        self.returnIP()

    def do_GET(self):
        self.returnIP()

server = HTTPServer(('', 8080), MyHandler)
server.handle_request()

