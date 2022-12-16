#!/bin/bash
echo  -e "

		__     ___    ___      __     
		\ \   / / |  | \ \    / /\    
		 \ \_/ /| |  | |\ \  / /  \   
		  \   / | |  | | \ \/ / /\ \  
		   | |  | |__| |  \  / ____ \ 
		   |_|   \____/    \/_/    \_\    1.1.0   
		     							
		     		-YUVARATNA PARVATANENI
"
# Prompt user for domain input
read -p "Enter a domain: " domain

# Make the new folder
mkdir All
cd All

# Confirm that the folder was created
if [ $? -eq 0 ]; then
  echo "The All folder was successfully created."
else
  echo "There was an error creating the All folder."
fi

# Validate the domain name
if ! [[ $domain =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
    echo  "Error: Invalid domain name"
    exit 1
fi

# Check if the output files already exist, and prompt the user to confirm overwriting them
output_files=(sub.txt livedomains.txt allUrls.txt liveallurls.txt dalfox.txt)
for file in "${output_files[@]}"; do
    if [ -f "$file" ]; then
        read -p "$file already exists, do you want to overwrite it? [y/n] " yn
        case $yn in
            [Yy]* ) rm "$file";;
            * ) echo "Cancelled" && exit;;
        esac
    fi
done

# Use ANSI escape codes to set the color of the messages
echo -e "\n\e[32mFinding subdomains for $domain using subfinder...\n\e[0m"
# Use subfinder to find subdomains for the given domain,
# then write the output to sub.txt
subfinder -max-time 1 -d "$domain" -all -silent -o sub1.txt

# Check the exit code of the previous command
if [ $? -ne 0 ]; then
    echo "Error: Failed to find subdomains using subfinder"
    exit 1
fi

# Use ANSI escape codes to set the color of the messages
echo -e "\n\e[32mFinding subdomains for $domain using amass...\n\e[0m"
# Use amass to find subdomains for the given domain,
# then write the output to amasssub.txt
amass enum -passive -d "$domain"  -o sub2.txt

# Check the exit code of the previous command
if [ $? -ne 0 ]; then
    echo "Error: Failed to find subdomains using amass"
    exit 1
fi


# Concatenate the output files into a single file
cat sub1.txt sub2.txt > subdomains.txt


# Print a success message
echo -e "\n Successfully mixed in subdomains"



echo -e "\n\e[32mFinding live subdomains using httprobe...\n\e[0m"
# Use httprobe to find live URLs for the subdomains,
# then write the output to livedomain.txt
cat subdomains.txt | httprobe -c 100 > livedomains.txt

# Check the exit code of the previous command
if [ $? -ne 0 ]; then
    echo "Error: Failed to find live URLs using httprobe"
    exit 1
fi

# Check for unique lines in the output file
cat livedomains.txt|sort | uniq  | tee -a uniq_livedomains.txt

# Print a success message
echo -e "\n Successfully checked unique domains in livedomains"

# Delete the input files
rm sub1.txt sub2.txt


echo -e "\n\e[32mFinding URLs using gau...\n\e[0m"
# Use gau to find URLs from the wayback machine,
# then write the output to allUrls.txt
cat uniq_livedomains.txt | gau --verbose --subs --blacklist png,jpg,gif,jpeg,swf,woff,gif,svg --o allUrls.txt

# Check the exit code of the previous command
if [ $? -ne 0 ]; then
    echo "Error: Failed to find URLs using gau"
    exit 1
fi

echo -e "\n\e[32mFinding live URLs using httpx...\n\e[0m"
# Use httpx to find live URLs from the wayback machine,
# then write the output to liveallurls.txt
cat allUrls.txt | httpx -mc 200,403 -o liveallurls.txt

echo -e "\n\e[32mFinding XSS vulnerabilities using dalfox...\n\e[0m"
# Use dalfox to find XSS vulnerabilities,
# then write the output to dalfox.txt
cat liveallurls.txt | gf xss | sed 's/=.*/=/' | sed 's/URL: //' | sort -u | dalfox pipe |tee xss.txt

echo -e "\n\e[32mProcess complete!\n\e[0m"

#---------------------- Sending Results to Telegram --------------------------------#

# Prompt user for domain input
# Set your bot token and chat ID
BOT_TOKEN=5599277543:AAH-D6I9GvzKtqs52B50wYHjA13aRtPVRWA
CHAT_ID=-1001830541420



# Set the path to the text file
FILE_PATH=/home/kali/Desktop/All/xss.txt

# Send the file to Telegram
curl -s -X POST https://api.telegram.org/bot$BOT_TOKEN/sendDocument -F chat_id=$CHAT_ID -F document=@$FILE_PATH
