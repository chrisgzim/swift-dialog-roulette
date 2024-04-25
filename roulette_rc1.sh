#!/bin/bash

bankfile="/tmp/bankroll.txt"
dialogBinary="/usr/local/bin/dialog"
commandfile=$( mktemp /var/tmp/bankrolldisplay.XXX )
information="You can bet a variety of ways: \n\nBet on the thirds (1/3, 2/3, 3/3): Expected Payout of 3x \n\nBet on Red,Black,1 to 18,19 to 36 or a Column: Expected Payout of 2x \n\nBet a Number (00-36): Expected payout of 35x \n\n*Note* At this time swiftDialog cannot accept \$ in a regex. So just enter the number of dollars you wish to wager."

function preflight() {
	# Check for Dialog and install if not found
	if [ ! -e "/Library/Application Support/Dialog/Dialog.app" ]; then
		
		echo "PRE-FLIGHT CHECK: swiftDialog not found. Installing..."
		dialogInstall
		
	else
		
		dialogVersion=$(/usr/local/bin/dialog --version)
		if [[ "${dialogVersion}" < "2.3.2.4726" ]]; then
			
			echo "PRE-FLIGHT CHECK: swiftDialog version ${dialogVersion} found but swiftDialog 2.3.2.4726 or newer is required; updating..."
			dialogInstall
			
		else
			
			echo "PRE-FLIGHT CHECK: swiftDialog version ${dialogVersion} found; proceeding..."
			
		fi
		
	fi
} 

function dialogInstall {
	
	# Get the URL of the latest PKG From the Dialog GitHub repo
	dialogURL=$(curl -L --silent --fail "https://api.github.com/repos/swiftDialog/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")
	
	# Expected Team ID of the downloaded PKG
	expectedDialogTeamID="PWA5E9TQ59"
	
	echo "PRE-FLIGHT CHECK: Installing swiftDialog..."
	
	# Create temporary working directory
	workDirectory=$( /usr/bin/basename "$0" )
	tempDirectory=$( /usr/bin/mktemp -d "/private/tmp/$workDirectory.XXXXXX" )
	
	# Download the installer package
	/usr/bin/curl --location --silent "$dialogURL" -o "$tempDirectory/Dialog.pkg"
	
	# Verify the download
	teamID=$(/usr/sbin/spctl -a -vv -t install "$tempDirectory/Dialog.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')
	
	# Install the package if Team ID validates
	if [[ "$expectedDialogTeamID" == "$teamID" ]]; then
		
		/usr/sbin/installer -pkg "$tempDirectory/Dialog.pkg" -target /
		sleep 2
		dialogVersion=$( /usr/local/bin/dialog --version )
		echo "PRE-FLIGHT CHECK: swiftDialog version ${dialogVersion} installed; proceeding..."
		
	else
		
		# Display a so-called "simple" dialog if Team ID fails to validate
		osascript -e 'display dialog "Please advise your Support Representative of the following error:\r\r• Dialog Team ID verification failed\r\r" with title "Setup Your Mac: Error" buttons {"Close"} with icon caution'
		echo "There was a problem with downloading swiftDialog. . . "
		completionActionOption="Quit"
		exitCode="1"
		exit 1
		
	fi
	
	# Remove the temporary working directory when done
	/bin/rm -Rf "$tempDirectory"
	
}

function updatedialogbox() {
	echo "$1" >> $commandfile
}

function editbankroll() {
	echo "\$${1}" > $bankfile
}

function createbankroll() {
		echo "checking for bankroll. . ."
	
	if [[ ! -e $bankfile ]]; then
		read -p "You haven't approached the table with any money, how much do you want to bring to the table? " bankroll
		if [[ $bankroll =~ ^\$[0-9]+$ ]]; then
			bankroll=$(echo $bankroll | sed 's/[^0-9]*//g' )
			editbankroll $bankroll
		elif [[ $bankroll =~ ^[0-9]+$ ]]; then
			editbankroll $bankroll
		else
			echo "You put something weird in the bankroll, currently we can only accept American denominations"
			exit 1
		fi
	fi
}

function presentwager() {
	bankroll=$(cat $bankfile)
	workfile="/tmp/roulette.txt"
	echo $bankroll
	if [[ ${bankroll/"\$"} -gt 0 ]]; then
		$dialogBinary \
		--title \Welcome\ To\ Roulette \
		--message \Choose\ Your\ Wager\ "\n\nCurrent Bankroll:"\ $bankroll \
		--icon \https://upload.wikimedia.org/wikipedia/commons/thumb/8/88/Basic_roulette_wheel.svg/1024px-Basic_roulette_wheel.svg.png \
		--helpmessage \ "$information" \
		--textfield \What\'s\ Your\ Bet?\,required \
		--textfield \What\'s\ Your\ Wager?\regex="^(1[5-9]|[2-9][0-9]|[1-9][0-9]+)$",regexerror="Either your bet is too low or you added a \$.(Currently swiftDialog regex does not support the ability to have a \$ in front. Please just use a number",required \
		--button1text \SPIN \ 2>&1 > $workfile
	else
		$dialogBinary \
		--title \Welcome\ To\ Roulette \
		--message \ "You are out of money. Better go to the ATM." \
		--icon \warning 
		rm -r $bankfile
		exit 1	
	fi
	wager=$(cat $workfile | grep "Wager" | awk '{print $NF}')
	echo $wager
	formatroll=$(echo $bankroll | sed 's/[^0-9]*//g')
	if [[ $wager -gt $formatroll ]]; then
		$dialogBinary \
		--title \Welcome\ To\ Roulette \
		--message \ "You bet more than you have available bankroll. Try Again." \
		--icon \warning 
		exit 1
	fi

	bankroll=$(( $formatroll - $wager ))
	bet=$(grep "Bet" $workfile | sed 's/[^,:]*://g; s/^[[:space:]]*//')
	echo "$bet is the bet"
	editbankroll $bankroll
	rm -r $workfile
}

function fixwager() {
	bankroll=$(( ${bankroll/\$ } + $wager ))
	editbankroll $bankroll
}

function checkbet() {
	#this allows you to not worry about case sensitivity for your case! 
	
	winningnumbers=()
	shopt -s nocasematch
	case $bet in 
		1/3 | 2/3 | 3/3 )
			payout=3
			if [[ $bet == "1/3" ]]; then
				winningnumbers='^(1[0-2]|[1-9])$'
			elif [[ $bet == "2/3" ]]; then
				winningnumbers="^(1[3-9]|2[0-4])$"
			elif [[ $bet == "3/3" ]]; then
				winningnumbers="^(2[5-9]|3[0-6])$"
			fi
		;;
		black | red | even | odd | "1 to 18" | "19 to 36" | "Column 1" | "Column 2" | "Column 3")
			payout=2
			if [[ $bet == "black" ]]; then
				winningnumbers=(2 4 6 8 10 11 13 15 17 20 22 24 26 28 29 31 33 35)
			elif [[ $bet == "red" ]]; then
				winningnumbers=(1 3 5 7 9 12 14 16 18 19 21 23 25 27 30 32 34 36)
			elif [[ $bet == "even" ]]; then
				winningnumbers='^([2468]|1[0-9]|2[0-9]|3[0-6])$'
			elif [[ $bet == "odd" ]]; then
				winningnumbers='^([13579]|1[0-9]|2[0-9]|3[0-6])$'
			elif [[ $bet == "1 to 18" ]]; then
				winningnumbers='^(1[0-8]|[1-9])$'
			elif [[ $bet == "19 to 36" ]]; then
				winningnumbers='^(1[9]|2[0-9]|3[0-6])$'
			elif [[ $bet == "Column 1" ]]; then
				winningnumbers=(1 4 7 10 13 16 19 22 25 28 31 34)
			elif [[ $bet == "Column 2" ]]; then
				winningnumbers=(2 5 8 11 14 17 20 23 26 29 32 35)
			elif [[ $bet == "Column 3" ]]; then
				winningnumbers=(3 6 9 12 15 18 21 24 27 30 33 36)
			fi
		;;
		[1-9]|1[0-9]|2[0-9]|3[0-6])
			payout=35
			winningnumbers+=($bet)
		;;
		0|00)
			payout=35
			winningnumbers+=($bet)
		;;
		*)
			$dialogBinary \
			--title \Welcome\ To\ Roulette \
			--message \ "$bet is not a valid bet. Please Try again" \
			--icon \warning 
			fixwager 
			exit 1
		;;
	esac
	
}

function spinthatwheel() {
	
	spinprompt="$dialogBinary \
	--title \SPINNING \
	--icon \https://upload.wikimedia.org/wikipedia/commons/thumb/8/88/Basic_roulette_wheel.svg/1024px-Basic_roulette_wheel.svg.png \
	--message \"You Feeling Lucky?\" \
	--progress \
	--progresstext \"The Wheel is Spinning\" \
	--button1text \"Wait\" \
	--button1disabled \
	--commandfile \"$commandfile\" "
	
	echo "$spinprompt" >> $commandfile
	eval ${spinprompt[*]} & sleep .3
	updatedialogbox "progress: 1"
	
	
	pid=$(( 100 / 4 ))
	
	for ((i=0; i<4; i++)); do
		sleep 5
		updatedialogbox "progress: increment ${pid}"
	done
	#arrays for fun
	roulettenumbers=(00 $(jot - 0 36))
	# the secret sauce behind our randomness 
	i=$(($RANDOM % (0 - 37)))
	winner=${roulettenumbers[$i]}
	updatedialogbox "message: The winning number is $winner. Let's see if you're a winner!"
	updatedialogbox "progress: complete"
	updatedialogbox "button1: enable"
	updatedialogbox "button1text: Continue"
	
}


function determinewinner() { 
	
	losermessage="The winning number was $winner. \n\nYour bet was made on: $bet. \n\nBetter luck next time. You lost a total of \$$wager. \n\nYour New Bankroll is: \$$bankroll."
	
	if [[ ${winningnumbers} =~ ^\^ ]]; then
		if [[ $winner =~ $winningnumbers ]]; then
			winnings=$(( $wager * $payout ))
			editbankroll $(( $winnings + $bankroll ))
			bankroll=$(cat $bankfile)
			winnermessage="The winning number was $winner. \n\nYour bet was made on: $bet. \n\nYOU DID IT, YOU WON! You won a total of \$$winnings. \n\nYour New Bankroll is: $bankroll"
			$dialogBinary \
			--title \WINNER \
			--message \ "$winnermessage" \
			--icon \https://upload.wikimedia.org/wikipedia/commons/thumb/8/88/Basic_roulette_wheel.svg/1024px-Basic_roulette_wheel.svg.png
		else
			bankroll=$(cat $bankfile)
			losermessage="The winning number was $winner. \n\nYour bet was made on: $bet. \n\nBetter luck next time. You lost a total of \$$wager. \n\nYour New Bankroll is: $bankroll."
			$dialogBinary \
			--title \LOSER \
			--message \ "$losermessage" \
			--icon \https://upload.wikimedia.org/wikipedia/commons/thumb/8/88/Basic_roulette_wheel.svg/1024px-Basic_roulette_wheel.svg.png
		fi
	else
		echo "This appears to NOT be a regex"
		if [[ ${#winningnumbers[@]} -eq 1 ]]; then
			if [[ $winningnumbers = $winner ]]; then
				winnings=$(( $wager * $payout ))
				editbankroll $(( $winnings + $bankroll ))
				bankroll=$(cat $bankfile)
				winnermessage="The winning number was $winner. \n\nYour bet was made on: $bet. \n\nYOU DID IT, YOU WON! You won a total of \$$winnings. \n\nYour New Bankroll is: $bankroll"
				$dialogBinary \
				--title \WINNER \
				--message \ "$winnermessage" \
				--icon \https://upload.wikimedia.org/wikipedia/commons/thumb/8/88/Basic_roulette_wheel.svg/1024px-Basic_roulette_wheel.svg.png
			else
				bankroll=$(cat $bankfile)
				losermessage="The winning number was $winner. \n\nYour bet was made on: $bet. \n\nBetter luck next time. You lost a total of \$$wager. \n\nYour New Bankroll is: $bankroll."
				$dialogBinary \
				--title \LOSER \
				--message \ "$losermessage" \
				--icon \https://upload.wikimedia.org/wikipedia/commons/thumb/8/88/Basic_roulette_wheel.svg/1024px-Basic_roulette_wheel.svg.png
			fi
		else
			found=false
			for num in ${winningnumbers[@]}; do
				if [ "$num" == "$winner" ]; then
					found=true
					break
				fi
			done
			
			if [[ "$found" == true ]]; then
				winnings=$(( $wager * $payout ))
				editbankroll $(( $winnings + $bankroll ))
				bankroll=$(cat $bankfile)
				winnermessage="The winning number was $winner. \n\nYour bet was made on: $bet. \n\nYOU DID IT, YOU WON! You won a total of \$$winnings. \n\nYour New Bankroll is: $bankroll"
				$dialogBinary \
				--title \WINNER \
				--message \ "$winnermessage" \
				--icon \https://upload.wikimedia.org/wikipedia/commons/thumb/8/88/Basic_roulette_wheel.svg/1024px-Basic_roulette_wheel.svg.png
			else
				bankroll=$(cat $bankfile)
				losermessage="The winning number was $winner. \n\nYour bet was made on: $bet. \n\nBetter luck next time. You lost a total of \$$wager. \n\nYour New Bankroll is: $bankroll."
				$dialogBinary \
				--title \LOSER \
				--message \ "$losermessage" \
				--icon \https://upload.wikimedia.org/wikipedia/commons/thumb/8/88/Basic_roulette_wheel.svg/1024px-Basic_roulette_wheel.svg.png
			fi

		fi
	fi
	
}

function keepgoing() {
	
	if [[ ${bankroll/\$} -gt 0 ]]; then
		$dialogBinary \
		--title \Keep\ Playing? \
		--message \Do\ you\ want\ to\ keep\ playing\ or\ leave? \
		--button1text \STAY \
		--button2text \LEAVE || true | echo "LEAVE"
	else
		$dialogBinary \
		--title \Welcome\ To\ Roulette \
		--message \ "You are out of money. Better go to the ATM." \
		--icon \warning 
		echo "LEAVE"
	fi
}

function cleanup() {
	echo "You're walking away with $bankroll"
	rm -r $bankfile
	rm -r $commandfile
	
}



if [[ ! -e $bankfile ]]; then
	createbankroll 
fi

until [[ $status == "LEAVE" ]]; do
	presentwager 
	checkbet
	spinthatwheel
	sleep .1
	determinewinner 
	sleep .1
	status=$(keepgoing)
done
cleanup 
