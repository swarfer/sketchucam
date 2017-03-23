@echo off
if exist help.html del index.html
if exist help.html move help.html index.html
php make.php *.html
