#!/bin/bash
####################################################################################################
#  QuickFix
####################################################################################################
#  Created by Wade Stewart on 5/27/15.
####################################################################################################
#### Edited on 10/19/20. Major function and logic cleanup. Added a "Network Check" utility that 
#### will be fleshed out in future versions.
##########################################################################################################
#### Edited on 2/27/20. CoacaDialog is replaced by Pachua for UI. Added ablility to run First AID,...
#### Keychain reset, launch Self Service, and manually select plist to remove. Log out added. 
##########################################################################################################
# This script will remove plists for the Applications below. Each Application has its own function
# in which you can place plist paths or other files that could be removed to fix common issues.
# If you add a function be sure to call it within an if statement at the bottom of the script.
# Be sure to use -f flag to force removal without errors and -rf for recursive to remove Directoies
##################################################################################################
MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
##################################################################################################
# Set Variables:
$maintenance = "jamfPolicyTrigger" #This is used in the "FirstAid" function to trigger Jamf to do a "Maintenance" policy. Insert the Jamf policy trigger here.
# Example: /usr/local/bin/jamf policy -event $maintenance
#
# The Network Function is based on using a Cisco Anyconnect VPN and Palo Alto Firewall.
paloIP="XX.XX.XX.XX" # IP address for user authentification to Palo Alto firewall.
host1="my.domain.com"   # host1 should be an intranet only site to test internal network access.
host2="www.cnn.com"     # host2 should be an external site that is NOT allowed through your firewall without User auth with Inet access.
host3="www.google.com"  # host3 should be an external site that is allowed through your firewall without restrictions.

##################################################################################################
# Include pashua.sh to be able to use the 2 functions defined in that file
# source "$MYDIR/pashua.sh"
# Tries to find the Pashua executable in one of a few default search locations or in
# a custom path passed as optional argument. When it can be found, the filesystem
# path will be in $pashuapath, otherwise $pashuapath will be empty. The return value
# is 0 if it can be found, 1 otherwise.
##################################################################################################
# Argument 1: Path to a folder containing Pashua.app (optional)
#################################################################################################
locate_pashua() {

    local bundlepath="Pashua.app/Contents/MacOS/Pashua"
    local mypath=`dirname "$0"`

    pashuapath=""

    if [ ! "$1" = "" ]
    then
        searchpaths[0]="$1/$bundlepath"
    fi
    searchpaths[1]="$mypath/Pashua"
    searchpaths[2]="$mypath/$bundlepath"
    searchpaths[3]="./$bundlepath"
    searchpaths[4]="/Applications/$bundlepath"
    searchpaths[5]="$HOME/Applications/$bundlepath"
    searchpaths[6]="/Users/Shared/$bundlepath"

    for searchpath in "${searchpaths[@]}"
    do
        if [ -f "$searchpath" -a -x "$searchpath" ]
        then
            pashuapath=$searchpath
            return 0
        fi
    done

    return 1
}
#################################################################################################
# Function for communicating with Pashua
#
# Argument 1: Configuration string
# Argument 2: Path to a folder containing Pashua.app (optional)
#################################################################################################
pashua_run() {

    # Write config file
    local pashua_configfile=`/usr/bin/mktemp /tmp/pashua_XXXXXXXXX`
    echo "$1" > "$pashua_configfile"

    locate_pashua "$2"

    if [ "" = "$pashuapath" ]
    then
        >&2 echo "Error: Pashua could not be found"
        exit 1
    fi

    # Get result
    local result=$("$pashuapath" "$pashua_configfile")

    # Remove config file
    rm "$pashua_configfile"

    oldIFS="$IFS"
    IFS=$'\n'

    # Parse result
    for line in $result
    do
        local name=$(echo $line | sed 's/^\([^=]*\)=.*$/\1/')
        local value=$(echo $line | sed 's/^[^=]*=\(.*\)$/\1/')
        eval $name='$value'
    done

    IFS="$oldIFS"
}
#################################################################################################
##### Conf 1 Initial diag box to get user input.
#################################################################################################
# Define what the dialog should be like
# Take a look at Pashua's Readme file for more info on the syntax
function diag1 {
    conf="
    # Set window title
    *.title = Quick Fix 3.0
    # Dropdown text
    txt.type = text
    txt.default = Quick Fix is an Applicaiton to help quickly troublshoot common issues with your computer. Please select from the options on the left to specify what type of issue you are experiencing.
    txt.height = 250
    txt.width = 250
    txt.x = 350
    txt.y = 150
    #txt.tooltip = This is an element of type “text”

    # Add a text field
    #tf.type = textfield
    #tf.label = Example textfield
    #tf.default = Textfield content
    #tf.width = 310
    #tf.tooltip = This is an element of type “textfield”

    # Library Path text
    txt2.type = text
    txt2.default = For an Application not listed above try opening to the following location and moving the corresponding plist to the trash. (ie com.vendor.application)
    txt2.height = 276
    txt2.width = 310
    txt2.x = 10
    txt2.y = 60

    # Checkbox text
    txt3.type = text
    txt3.default = What other function would you like to run?
    txt3.x = 10
    txt3.y = 230

    # Add 2 checkboxes
    chk.x = 10
    chk.y = 200
    chk.type = checkbox
    chk.label = Run macOS First Aid
    #chk.tooltip = This is an element of type “checkbox”
    #chk.default = 1
    chk2.x = 10
    chk2.y = 175
    chk2.type = checkbox
    chk2.label = Reset Keychain Passwords
    #chk2.disabled = 1
    #chk2.tooltip = Another element of type “checkbox”
    chk3.x = 10
    chk3.y = 150
    chk3.type = checkbox
    chk3.label = Open Self Service
    chk5.x = 10
    chk5.y = 125
    chk5.type = checkbox
    chk5.label = Internet / Network Issues
    #chk4.x = 10
    #chk4.y = 100
    #chk4.type = checkbox
    #chk4.label = Reboot after finishing

    # Add a filesystem browser
    ob.type = openbrowser
    ob.label = Open the Library Directory
    ob.default = ~/Library/Preferences/
    ob.filetype = plist
    ob.width=310
    ob.x = 10
    ob.y = 10
    #ob.tooltip = This is an element of type “openbrowser”

    # Define radiobuttons
    #rb.type = radiobutton
    #rb.label = Example radiobuttons
    #rb.option =
    #rb.option =
    #rb.tooltip = This is an element of type “radiobutton”

    # Add a popup menu
    pop.type = popup
    pop.label = What Application are you having issues with?
    pop.width = 310
    pop.option = None
    pop.default = None
    pop.option = Google Chrome
    pop.option = Firefox
    pop.option = Safari
    pop.option = Microsoft Office
    pop.option = Adobe Acrobat
    pop.option = Adobe Photoshop
    pop.option = Adobe Illustrator
    pop.option = Adobe InDesign
    pop.option = Adobe Dreamweaver
    pop.option = Capture One
    pop.x = 10
    pop.y = 270
    #pop.tooltip = This is an element of type “popup”

    # Add a cancel button with default label
    cb.type = cancelbutton
    #cb.tooltip = This is an element of type “cancelbutton”

    db.type = defaultbutton
    #db.tooltip = This is an element of type “defaultbutton” (which is automatically added to each window, if not included in the configuration)
    "

    if [ -d '/Volumes/Pashua/Pashua.app' ]
    then
    	# Looks like the Pashua disk image is mounted. Run from there.
    	customLocation='/Volumes/Pashua'
    else
    	# Search for Pashua in the standard locations
    	customLocation=''
    fi

    # Get the icon from the application bundle
    locate_pashua "$customLocation"
    bundlecontents=$(dirname $(dirname "$pashuapath"))
    if [ -e "$bundlecontents/Resources/AppIcon@2.png" ]
    then
        conf="$conf
              img.type = image
              img.x = 400
              img.y = 220
              img.maxwidth = 128
              #img.tooltip = This is an element of type “image”
              img.path = $bundlecontents/Resources/quickfix.png"
    fi

    pashua_run "$conf" "$customLocation"
    #
    # Cancel here if the user clicks the cancel button
    #
    if [ $cb -eq 1 ]
    then
        exit 0
    fi
    #################################################################################################
    # Set the output to variables to decide what to do from the UI input
    #################################################################################################
    App=$pop
    Cancel=$cb
    FirstAID=$chk
    Keychain=$chk2
    SS=$chk3
    Network=$chk5
    Plist=$ob
}
#################################################################################################
##### Conf 2 Window to display network information .
#################################################################################################
function diag2 {
    conf2="
    # Set window title
    *.title = Quick Fix 3.0
    *.height = 50
    *.width = 50
    # Dropdown text
    txt.type = text
    txt.default = Network Check Complete:[return][return]$netStat[return][return]$vpnStatus
    txt.height = 250
    txt.width = 250
    txt.x = 20
    txt.y = 80



    # Add a cancel button with default label
    cb.type = cancelbutton
    #cb.tooltip = This is an element of type “cancelbutton”


    logout.type = defaultbutton
    logout.label = Ok
    #db.tooltip = This is an element of type “defaultbutton” (which is automatically added to each window, if not included in the configuration)
    "

    if [ -d '/Volumes/Pashua/Pashua.app' ]
    then
    	# Looks like the Pashua disk image is mounted. Run from there.
    	customLocation='/Volumes/Pashua'
    else
    	# Search for Pashua in the standard locations
    	customLocation=''
    fi

    # Get the icon from the application bundle
    locate_pashua "$customLocation"
    bundlecontents=$(dirname $(dirname "$pashuapath"))
    if [ -e "$bundlecontents/Resources/AppIcon@2.png" ]
    then
        conf2="$conf2
              img.type = image
              img.x = 80
              img.y = 180
              img.maxwidth = 128
              #img.tooltip = This is an element of type “image”
              img.path = $bundlecontents/Resources/quickfix.png"
    fi

    pashua_run "$conf2" "$customLocation"
}
#################################################################################################
##### Conf 3 Log out message in case the process requires it.
#################################################################################################
function diag3 {
    conf3="
    # Set window title
    *.title = Quick Fix 3.0
    *.height = 50
    *.width = 50
    # Dropdown text
    txt.type = text
    txt.default = To complete the task you will need to log off and back on to your machine. PLEASE SAVE ALL WORK BEFORE PROCEEDING.
    txt.height = 250
    txt.width = 250
    txt.x = 20
    txt.y = 80



    # Add a cancel button with default label
    cb.type = cancelbutton
    #cb.tooltip = This is an element of type “cancelbutton”


    logout.type = defaultbutton
    logout.label = Ok
    #db.tooltip = This is an element of type “defaultbutton” (which is automatically added to each window, if not included in the configuration)
    "

    if [ -d '/Volumes/Pashua/Pashua.app' ]
    then
    	# Looks like the Pashua disk image is mounted. Run from there.
    	customLocation='/Volumes/Pashua'
    else
    	# Search for Pashua in the standard locations
    	customLocation=''
    fi

    # Get the icon from the application bundle
    locate_pashua "$customLocation"
    bundlecontents=$(dirname $(dirname "$pashuapath"))
    if [ -e "$bundlecontents/Resources/AppIcon@2.png" ]
    then
        conf3="$conf3
              img.type = image
              img.x = 80
              img.y = 180
              img.maxwidth = 128
              #img.tooltip = This is an element of type “image”
              img.path = $bundlecontents/Resources/quickfix.png"
    fi

    pashua_run "$conf3" "$customLocation"
    ####################################################################################
    # When everything is finished and the user clicks "Logout" button, well, log out. ##
    ####################################################################################
    echo " Logout is commented out."
    #if [[ $logout == "1" ]]; then
    #    pkill loginwindow
    #fi
}
#################################################################################################
##### Conf 4 Message to user that Quick Fix has finished and does not require a logout.
#################################################################################################
function diag4 {
    conf4="
    # Set window title
    *.title = Quick Fix 3.0
    *.height = 50
    *.width = 50
    # Dropdown text
    txt.type = text
    txt.default = Quick Fix has finished.
    txt.height = 250
    txt.width = 250
    txt.x = 20
    txt.y = 80



    # Add a cancel button with default label
    cb.type = cancelbutton
    #cb.tooltip = This is an element of type “cancelbutton”


    logout.type = defaultbutton
    logout.label = Ok
    #db.tooltip = This is an element of type “defaultbutton” (which is automatically added to each window, if not included in the configuration)
    "

    if [ -d '/Volumes/Pashua/Pashua.app' ]
    then
    	# Looks like the Pashua disk image is mounted. Run from there.
    	customLocation='/Volumes/Pashua'
    else
    	# Search for Pashua in the standard locations
    	customLocation=''
    fi

    # Get the icon from the application bundle
    locate_pashua "$customLocation"
    bundlecontents=$(dirname $(dirname "$pashuapath"))
    if [ -e "$bundlecontents/Resources/AppIcon@2.png" ]
    then
        conf4="$conf4
              img.type = image
              img.x = 80
              img.y = 180
              img.maxwidth = 128
              #img.tooltip = This is an element of type “image”
              img.path = $bundlecontents/Resources/quickfix.png"
    fi

    pashua_run "$conf4" "$customLocation"
}
####################################################################################
######## Declaring Functions for Selected Applicaiton actions to be taken ##########
####################################################################################
#
# Remove Acrobat Preferences
#
function AcrobatRM {
    pkill Acrobat*
    rm -f ~/Library/Preferences/com.adobe.Acrobat.*
    rm -rf ~/Library/Saved\ Application\ State/com.adobe.Acrobat*
}
#
# Remove Illustrator Preferences
#
function IllustratorRM {
    pkill Adobe Illustrator*
    rm -f ~/Library/Preferences/com.adobe.illustrator.*
    rm -rf ~/Library/Saved\ Application\ State/com.adobe.Illustrator*
}
#
# Remove Photoshop Preferences
#
function PhotoshopRM {
    pkill Adobe Bridge*
    pkill Adobe Photoshop*
    rm -f ~/Library/Preferences/com.adobe.Photoshop.*
    rm -f ~/Library/Preferences/com.adobe.bridge*
    rm -rf ~/Library/Saved\ Application\ State/com.adobe.Photoshop*
    rm -rf ~/Library/Saved\ Application\ State/com.adobe.bridge*
}
#
# Remove InDesign Preferences
#
function InDesignRM {
    pkill Adobe InDesign*
    rm -f ~/Library/Preferences/com.adobe.InDesign.*
    rm -rf ~/Library/Saved\ Application\ State/com.adobe.InDesign*
    rm -rf ~/Library/Preferences/Adobe\ InDesign/Version*
    rm -rf ~/Library/Caches/Adobe\ InDesign/Version*
}
#
# Remove DreamWeaver Preferences
#
function DreamweaverRM {
    pkill Adobe Dreamweaver*
    rm -f ~/Library/Preferences/com.adobe.Dreamweaver.*
    rm -rf ~/Library/Saved\ Application\ State/com.adobe.Dreamweaver*
    rm -rf ~/Library/Preferences/Adobe\ Dreamweaver/Version*
    rm -rf ~/Library/Caches/Adobe\ Dreamweaver/Version*
}
#
# Remove Chrome Preferences
#
function ChromeRM {
    pkill Google Chrome
    rm -f ~/Library/Preferences/com.google.*
    rm -rf ~/Library/Caches/Google/
    rm -rf ~/Library/Caches/com.google.Chrome/
    rm -rf ~/Library/Saved\ Application\ State/com.google.*
    rm -rf ~/Library/Application\ Support/Google/Chrome/Default/Cookies
}
#
# Remove Firefox Preferences
#
function FirefoxRM {
    pkill Firefox
    rm -f ~/Library/Preferences/org.mozilla.*
    rm -rf ~/Library/Caches/Firefox/
}
#
# Remove Office Preferences
#
function OfficeRM {
    pkill Excel
    pkill Word
    pkill PowerPoint
    rm -f ~/Library/Preferences/com.microsoft.*
    rm -rf ~/Library/Caches/Microsoft\ Office/
    rm -rf ~/Library/Caches/com.microsoft.Word/
    rm -rf ~/Library/Saved\ Application\ State/com.microsoft.*
    rm -rf ~/Library/Group\ Containers/*.Office
}
#
#Remove Safari Preferences
#
function SafariRM {
    pkill Safari
    rm -f ~/Library/Preferences/com.apple.Safari.*
    rm -rf ~/Library/Caches/com.apple.Safari*/
    rm -rf ~/Library/Safari/LocalStorage/
}
#
#Remove Capture One Preferences
#
function CaptureRM {
    pkill Capture One
    rm -f ~/Library/Preferences/com.phaseone.*/
    rm -f ~/Library/Preferences/com.phaseone.*/
}
####################################################################################
############ Case the results to run the appropriate function ######################
####################################################################################
function appFix { 
    case "$App" in
        "Google Chrome" ) 
        	ChromeRM
            ;;
        "Firefox" ) 
        	FirefoxRM
            ;;
        "Safari" ) 
           	SafariRM
            ;;
        "Microsoft Office" ) 
        	OfficeRM
            ;;
        "Capture One" ) 
        	CaptureRM
    		;;    
        "Adobe Acrobat" ) 
    		AcrobatRM
    		;;
    	"Adobe Photoshop")
    	    PhotoshopRM
    		;;
    	"Adobe InDesign")
    		InDesignRM
    		;;
    	"Adobe Illustrator")
    		IllustratorRM
    		;;
    	"Adobe Bridge")
    		PhotoshopRM
    		;;
    	"Adobe Dreamweaver")
    		DreamweaverRM
    		;;
    esac
   #echo "App Fix Ran" 
}
####################################################################################
################################ Check box logic ###################################
####################################################################################
function checkBoxFix {    
    #
    # Do you run First Aid?
    #
    if [[ $FirstAID == "1" ]]; then
            echo Run First Aid
            /usr/local/bin/jamf policy -event $maintenance
    fi
    #
    # Do you Open Self Service?
    #
    if [[ $SS == "1" ]]; then
            echo Open Self Service
            open -a Self\ Service
    fi
    #
    # Do you remove a users .plist file?
    #
    if [[ $Plist == *".plist" ]]; then
            echo Remove plist
            rm $Plist
    fi
    #
    # Do you reset the users keychain?
    #
    if [[ $Keychain == "1" ]]; then
            echo Reset Keychain
            user=$(ls -l /dev/console | awk '{print $3}')
            rm -R /Users/$user/Library/Keychains
    fi
    #
    # Network Status check.
    #
    if [[ $Network == "1" ]]; then
            #echo "Did Network Check..."
            networkFunction
    fi
    #
    # Flush DNS
    #
    dscacheutil -flushcache
    #killall -HUP mDNSResponder
    #
    #echo "Check Box Fix Ran"
}
##################################################################################################################################
# Function to test network configuration:
# List of sites to ping. host1 = internal, host2 = external(blocked by firewall), host3 = external (allowed by firewall)
##################################################################################################################################
function networkFunction {
    paloAuth=$(curl -s $paloIP | grep "title" | sed 's/<\/div>/\n/')
    ##################################################################################################################################
    # Ping each host with 30 ms for a reply. Set var to UP or DOWN.
    ##################################################################################################################################
    result=`ping -W 30 -c 1 $host1 | grep 'bytes from '`
        if [ $? -gt 0 ]; then
            internalResults="DOWN"
        else
            internalResults="UP"
        fi
        #echo $internalResults
    result=`ping -W 30 -c 1 $host2 | grep 'bytes from '`
        if [ $? -gt 0 ]; then
            externalResults="DOWN"
        else
            externalResults="UP"
        fi
        #echo $externalResults
    result=`ping -W 30 -c 1 $host3 | grep 'bytes from '`
        if [ $? -gt 0 ]; then
            allowedResults="DOWN"
        else
            allowedResults="UP"
        fi
        #echo $allowedResults
    ##################################################################################################################################
    # Compare the variables from above to determine current network state.
    ##################################################################################################################################
    if [[ "$internalResults" != "UP" && "$externalResults" != "UP" && "$allowedResults" != "UP" ]]; then
        #echo "No Network Connection"
        netStat="No Network Connection"
    fi
    #if [[ "$internalResults" == "UP" && "$externalResults" != "UP" && "$allowedResults" == "UP" ]]; then
    #fi
    ########## Check to see if user is authenticated to PaloAlto firewall ##########
        if [[ $paloAuth == "<title>Fastly error: unknown domain $paloIP</title>" ]];
            then
            paloStat="Possible issue with internal network routing."
            else
            #echo "No Palo Auth"
            open http://$paloIP
            paloStat="Firewall not authenticated, Please log in."
        fi
    ################################################################################  
    if [[ "$internalResults" != "UP" && "$externalResults" == "UP" && "$allowedResults" == "UP" ]]; then
        #echo "Not on Internal Network"
        netstat="Not on Internal Network"
    fi 
    if [[ "$internalResults" == "UP" && "$externalResults" == "UP" && "$allowedResults" == "UP" ]]; then
        #echo "On Internal Network"
        netStat="Internal and External networks are accessible"
    fi 
    ##################################################################################################################################
    # Check VPN Status
    ##################################################################################################################################
    if [[ "{$(/opt/cisco/anyconnect/bin/vpn status)[0]}" == *"Disconnected"* ]]; then
        vpnStatus="VPN Disconnected"
        #echo "Disconnected"
        elif [[ "{$(/opt/cisco/anyconnect/bin/vpn status)[0]}" == *"Connected"* ]]; then
            vpnStatus="VPN Connected"
            #echo "Connected"
                elif [ ! -d /opt/cisco/anyconnect/ ]; then
                vpnStatus="VPN Not Installed"
                #echo "Not Installed"
    fi
    #echo "VPN $vpnStatus"
    diag2
}
#################################################################################################
# echo the output from the UI to test that it is working....
#################################################################################################
function showUserInput {
    echo "Pashua created the following variables:"
    #echo "  tb  = $tb"
    #echo "  tf  = $tf"
    echo "  App = $pop"
    #echo "  rb  = $rb"
    echo "  Cancel = $cb"
    echo "  FirstAID = $chk"
    echo "  Keychain = $chk2"
    echo "  SS = $chk3"
    echo "  Network = $chk5"
    #echo "  Reboot = $chk4"
    echo "  Plist  = $ob"
}
##################################################################################################################################################################################################
##################################################################################################################################################################################################
# Put it all together with some stupid simple logic and you have the below script:
##################################################################################################
diag1; checkBoxFix
if [[ $App != "None" ]]; then
    appFix; diag3
    else
        diag4
fi
if [[ $Keychain = 1 ]]; then
    diag3
fi
exit 0
