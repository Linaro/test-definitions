Generate self signed certificate without SAN extensions

```
openssl genrsa -aes256 -passout pass:gsahdg -out server.pass.key 4096
openssl rsa -passin pass:gsahdg -in server.pass.key -out server.key
rm server.pass.key
openssl req -new -key server.key -out server.csr -subj "/C=US/ST=Oregon/L=Portland/O=Company Name/OU=Org/CN=localhost"
openssl x509 -req -sha256 -days 3650 -in server.csr -signkey server.key -out server.crt
```

Make curl trust the generated certificate

```
curl --cacert server.crt  --output index.html https://localhost
```
