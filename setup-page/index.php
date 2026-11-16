<?php
// Served only while the first-boot install runs, so visitors see a status page
// instead of a connection error. It answers 503 so Railway's health check waits
// for SuiteCRM itself.
http_response_code(503);
header('Content-Type: text/html; charset=utf-8');
header('Retry-After: 30');
?><!doctype html><html><head><meta charset="utf-8"><meta http-equiv="refresh" content="20"><title>SuiteCRM is starting</title></head>
<body style="font-family:sans-serif;max-width:40em;margin:4em auto">
<h1>SuiteCRM is being set up</h1>
<p>The first start copies SuiteCRM onto its volume and installs the database. This takes a few minutes. This page reloads itself.</p>
</body></html>
