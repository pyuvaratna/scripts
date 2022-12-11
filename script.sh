#!/bin/bash

# Prompt user for domain input
read -p "Enter a domain: " domain

# Use ANSI escape codes to set the color of the messages
echo -e "\n\e[32mFinding subdomains for $domain using subfinder...\n\e[0m"
# Use subfinder to find subdomains for the given domain,
# then write the output to sub.txt
subfinder -d $domain -all -silent -o sub.txt

echo -e "\n\e[32mFinding live URLs for the subdomains using httprobe...\n\e[0m"
# Use httprobe to find live URLs for the subdomains,
# then write the output to livedomain.txt
cat sub.txt | httprobe > livedomain.txt

echo -e "\n\e[32mFinding URLs using gau...\n\e[0m"
# Use gau to find URLs from the wayback machine,
# then write the output to allUrls.txt
cat livedomain.txt | gau --subs --blacklist png,jpg,gif,jpeg,swf,woff,gif,svg --o allUrls.txt

echo -e "\n\e[32mFinding live URLs using httpx...\n\e[0m"
# Use httpx to find live URLs from the wayback machine,
# then write the output to liveallurls.txt
cat allUrls.txt | httpx -mc 200,403 -o liveallurls.txt

echo -e "\n\e[32mFinding XSS vulnerabilities using dalfox...\n\e[0m"
# Use dalfox to find XSS vulnerabilities,
# then write the output to dalfox.txt
cat liveallurls.txt | gf xss | sed 's/=.*/=/' | sed 's/URL: //' | sort -u | dalfox pipe

echo -e "\n\e[32mProcess complete!\n\e[0m"
