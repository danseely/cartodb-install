# Notes on using CartoDB

## API

Call to upload local CSV file

```bash
curl -v -F file=@/path/to/file.csv "http://development.localhost.lan:3000/api/v1/imports/?api_key=API-KEY-HERE"
```

Call to run query via api

```bash
http://development.localhost.lan:8080/api/v1/sql?q=SELECT * FROM some_table&api_key=API-KEY-HERE
```