#!/bin/bash
# Prompt user for input
read -p "Enter a domain name or the path to a text file: " input


echo  -e "

		__     ___    ___      __     
		\ \   / / |  | \ \    / /\    
		 \ \_/ /| |  | |\ \  / /  \   
		  \   / | |  | | \ \/ / /\ \  
		   | |  | |__| |  \  / ____ \ 
		   |_|   \____/    \/_/    \_\    1.1.0   
		     							
		     		-YUVARATNA PARVATANENI
"

# Check if the input is a domain name
if [[ $input =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9].[a-zA-Z]{2,}$ ]]; then
  # Input is a domain name
  domain=$input
  
  
  # Make the new folder
  mkdir Target
  cd Target

  # Confirm that the folder was created
  if [ $? -eq 0 ]; then
    echo "The Target folder was successfully created."
  else
    echo "There was an error creating the Target folder."
  fi
  
  whois $domain | tee -a whoisMain.txt
  host $domain | tee -a hostInfo.txt
  dig $domain any | tee -a digInfo.txt

  
  echo -e "\n\e[32mFinding subdomains for $domain using amass...\n\e[0m"
  amass enum -passive -d $domain -o subdomains.txt

  # Check if subfinder and amass were successful
  if [ $? -ne 0 ]; then
    echo "Error: subfinder and amass failed to find subdomains for $domain"
    exit 1
  fi
  
  echo -e "\n\e[32mFinding live subdomains using httprobe...\n\e[0m"
  cat subdomains.txt | httprobe -c 100 > livedomains.txt

  # Check for unique lines in the output file
  cat livedomains.txt|sort | uniq  | tee -a uniq_livedomains.txt

  echo -e "\n\e[32m Checking for Sub-domain TakeOver using subjack...\n\e[0m" 
  subjack -v -w /home/kali/Desktop/Target/uniq_livedomains.txt -o subdomain_takeover.txt
 
 
  echo -e "\n\e[32mFinding URLs using gau...\n\e[0m"

  cat uniq_livedomains.txt | gau --verbose --subs --blacklist png,jpg,gif,jpeg,swf,woff,gif,svg --o allUrls.txt

  # Check if gau was successful
  if [ $? -ne 0 ]; then
    echo "Error: gau failed to find URLs for $domain"
    exit 1
  fi

  echo -e "\n\e[32mFiltering URLs and finding other information for $domain using httpx...\n\e[0m"
  cat allUrls.txt | httpx -mc 200,403 -o liveallurls.txt 

  
  # Check if httpx was successful
  if [ $? -ne 0 ]; then
    echo "Error: httpx failed to filter URLs and find other information for $domain"
    exit 1
  fi

  
  echo -e "\n\e[32m Differentiating URLs and finding XSS vulnerabilities for $domain using gf and dalfox...\n\e[0m"
  cat liveallurls.txt | gf xss | sed 's/=.*/=/' | sed 's/URL: //' | sort -u | dalfox pipe |tee xss.txt

  cat liveallurls.txt | gf xss | qsreplace '"><svg onload=confirm(1)>' | airixss -payload "confirm(1)" | tee xss2.txt
  
  
  echo -e "\n\e[32m GF patterns scan.. \n\e[0m"
  mkdir gfPatternsScan

 
  cat liveallurls.txt | gf redirect | tee -a gfPatternsScan/redirectGf.txt
  cat liveallurls.txt | gf ssti | tee -a gfPatternsScan/sstiGf.txt
  cat liveallurls.txt | gf sqli | tee -a gfPatternsScan/sqliGf.txt
  cat liveallurls.txt | gf rce | tee -a gfPatternsScan/rceGf.txt
  cat liveallurls.txt | gf lfi | tee -a gfPatternsScan/lfiGf.txt
  cat liveallurls.txt | gf ssrf | tee -a gfPatternsScan/ssfrparamsGf.txt
  
  
  echo -e "\n\e[32m Scanning with nuclei...\n\e[0m"
  nuclei -l uniq_livedomains.txt -rl 10 -o nuclei_results.txt

  echo -e "\n\e[32m Finding Directories using dirsearch...\n\e[0m"
  dirsearch -l /home/kali/Desktop/Target/uniq_livedomains.txt -i 200 -o /home/kali/Desktop/Target/Directories.txt
 	
  echo -e "\n\e[32mProcess complete!\n\e[0m"

  # Check if gf and dalfox were successful
  if [ $? -ne 0 ]; then
    echo "Error: gf and dalfox failed to differentiate URLs and find XSS vulnerabilities for $domain"
    exit 1
  fi
  
  #---------------------- Sending Results to Telegram --------------------------------#

  # Prompt user for domain input
  # Set your bot token and chat ID
  BOT_TOKEN=5599277543:AAH-D6I9GvzKtqs52B50wYHjA13aRtPVRWA
  CHAT_ID=-1001830541420



  # Set the path to the text file
  FILE_PATH=/home/kali/Desktop/Target/subdomain_takeover.txt

  # Send the file to Telegram
  curl -s -X POST https://api.telegram.org/bot$BOT_TOKEN/sendDocument -F chat_id=$CHAT_ID -F document=@$FILE_PATH

else
  # Input is not a domain name, so check if it is a file path
  if [ ! -f "$input" ]; then
    echo "Error: Invalid file path"
    exit 1
  fi

  # Read the domains from the file
  domains=$(cat "$input")

  
  echo "Finding URLs and other information for $domains using gau and httpx..."
  
  # Check if gau and httpx were successful
  if [ $? -ne 0 ]; then
    echo "Error: gau and httpx failed to find information for $domains"
    exit 1
  fi

  echo "Differentiating URLs and finding XSS vulnerabilities for $domains using gf and dalfox..."
  gf ip | dalfox -f - -o dalfox.txt | gf xss | tee -a results.txt

  # Check if gf and dalfox were successful
  if [ $? -ne 0 ]; then
    echo "Error: gf and dalfox failed to differentiate URLs and find XSS vulnerabilities for $domains"
    exit 1
  fi
fi
