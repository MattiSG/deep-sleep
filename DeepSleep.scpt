(*Author : Matti Schneider
*)
set appName to "Deep Sleep"
set theVersion to "2.1ß"
set theIcon to path to resource "DeepSleep.icns"
set descriptionFile to path to resource "Manuel de Deep Sleep.rtfd"

property onLaunchMode : 1
property usualMode : 0
property isLaptop : ""
property isOnAC : ""

property quickSleep : "Veille rapide"
property safeSleep : "Veille sécurisée"
property deepSleep : "Hibernation"
property modesList : {quickSleep, safeSleep, deepSleep}

(*Checks*)
checkOSVersion(getOSVersion())

(*Is the computer a laptop or not ? Moreover, get the current powering mode.*)
set isLaptop to do shell script "pmset -g | grep -q attery; echo $?"
if translateBool(isLaptop) then
	set isLaptop to true
	set isOnAC to isItOnAC() -- we use the method only here because we don't want to modify the behaviour of the script during its execution, which could happen if the user disconnected his computer during the execution
else
	set isLaptop to false
	set isOnAC to true
end if

(*Manage preferences*)
set hasBeenInitialized to do shell script "ls ~/Library/Preferences/com.mattisg.deepsleep.plist > /dev/null 2>/dev/null; echo $?"
if translateBool(hasBeenInitialized) then
	getPrefs()
else
	set choice to display dialog appName & " permet de modifier le mode de veille par défaut, et d'en utiliser un alternatif." & return & "Vous allez à présent configurer les modes de veilles à utiliser." buttons {"Quitter", "Manuel", "Ok"} default button 3 with title appName & " " & theVersion with icon theIcon
	if choice is {button returned:"Ok"} then
		setPrefs()
		set choice to display dialog "Parfait, il vous suffira à présent de lancer Deep Sleep pour passer en mode de veille alternatif." buttons {"OK"} default button 1 with icon theIcon
		realQuit()
	else
		if choice is {button returned:"Manuel"} then
			tell application "Finder"
				open file descriptionFile
			end tell
			realQuit()
		else
			realQuit()
		end if
	end if
end if

(*Let's roll !*)
do shell script "sudo pmset hibernatemode " & getCode(onLaunchMode) with administrator privileges
tell application "System Events"
	sleep
end tell

--following will be executed only when waking from sleep

do shell script "sudo pmset hibernatemode " & getCode(usualMode) with administrator privileges
try
	do shell script "sudo rm " & getTheVMFile() with administrator privileges
end try

quit

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


(*CHEKING METHODS*)
property major : 0 --version of the OS
property minor : 0

on getOSVersion()
	try
		set major to do shell script "sysctl -n kern.osrelease | cut -d '.' -f 1"
		set minor to do shell script "sysctl -n kern.osrelease | cut -d '.' -f 2"
	on error
		return false
	end try
	return true
end getOSVersion

on checkOSVersion(wasOk)
	if (wasOk and ((major is 8 and minor is greater than 2) or major is greater than 8)) then
		return true
	else
		display dialog "Version du système non supportée ! Vous devez avoir au moins Mac OS X 10.4.3 pour utiliser la fonction hibernation." buttons {"Quitter"} default button 1 with icon stop
		realQuit()
	end if
end checkOSVersion

on isItOnAC()
	set thePowerMode to do shell script "pmset -g | grep '*' | grep -q 'AC'; echo $?" --get current power mode
	return translateBool(thePowerMode)
end isItOnAC
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


(*GETTING SYSTEM PREFS FOR HIBERNATION*)
on getEncryptionState()
	try
		set useEncryptedSwap to do shell script "defaults read /Library/Preferences/com.apple.virtualMemory UseEncryptedSwap"
		if translateBool(useEncryptedSwap) then
			return 4 --an int, since the codes are 1 or 3 without encryption and 5 or 7 with it ; therefore, encryptionState is 0 or 4, and we'll calculate the code to use by summing
		else
			return 0
		end if
	on error --that is, the pref file isn't here. This happens if the user hasn't changed the default state…
		if major is greater than 8 then --…which is true in Leopard (and presumably future systems too) and false in Tiger
			return 4
		else
			return 0
		end if
	end try
end getEncryptionState

on getTheVMFile()
	set theVMFiles to do shell script "defaults read /Library/Preferences/SystemConfiguration/com.apple.PowerManagement | grep '\"Hibernate File\"' | cut -d \"=\" -f 2 | sed s/'[\" ;]'//g" --returns the AC Power hibernation file on first line and the Battery Power hibernation file on the second one
	if isOnAC then
		return paragraph 1 of theVMFiles
	else
		return paragraph 2 of theVMFiles
	end if
end getTheVMFile


on getCode(wantedMode)
	if wantedMode is quickSleep then
		return 0
	end if
	if wantedMode is safeSleep then
		return 3 + getEncryptionState()
	end if
	if wantedMode is deepSleep then
		return 1 + getEncryptionState()
	end if
	error --will be attained only if no value is returned. I use this instead of an "else" to test if it is deepSleep in order to protect the hibernatemode to be corrupted
end getCode
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


(*MANAGING PREFS AND GETTING USER INPUT*)
on chooseFromList(thePrompt, defaultMode)
	set theItem to choose from list modesList with prompt thePrompt default items {defaultMode} cancel button name "Quitter" without multiple selections allowed and empty selection allowed
	if theItem is false then
		realQuit()
	else
		return theItem
	end if
end chooseFromList

on setPrefs()
	if isLaptop then
		set AC_parentheses to " (sur secteur)"
		set Battery_parentheses to " (sur batterie)"
	else
		set AC_parentheses to ""
		set Battery_parentheses to ""
	end if

	do shell script "defaults write com.mattisg.deepsleep AC_usualMode '" & chooseFromList("Choisissez le mode de veille à utiliser en temps normal" & AC_parentheses & " :", quickSleep) & "'"
	do shell script "defaults write com.mattisg.deepsleep AC_onLaunchMode '" & chooseFromList("Choisissez le mode de veille à utiliser en lançant Deep Sleep" & AC_parentheses & " :", deepSleep) & "'"
	if isLaptop then
		do shell script "defaults write com.mattisg.deepsleep Battery_usualMode '" & chooseFromList("Choisissez le mode de veille à utiliser en temps normal" & Battery_parentheses & " :", quickSleep) & "'"
		do shell script "defaults write com.mattisg.deepsleep Battery_onLaunchMode '" & chooseFromList("Choisissez le mode de veille à utiliser en lançant Deep Sleep" & Battery_parentheses & " :", deepSleep) & "'"
	end if
end setPrefs

on getPrefs()
	if isOnAC then
		set prefix to "AC_"
	else
		set prefix to "Battery_"
	end if
	try
		set onLaunchMode to do shell script "defaults read com.mattisg.deepsleep " & prefix & "onLaunchMode"
		set usualMode to do shell script "defaults read com.mattisg.deepsleep " & prefix & "usualMode"
	on error
		display dialog "Les préférences de Deep Sleep sont illisibles. Veuillez choisir à nouveau vos préférences." with icon caution
		setPrefs()
	end try
end getPrefs
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


(*MISCELLANEOUS*)
on translateBool(int)
	if int is "0" then
		return true
	else
		return false
	end if
end translateBool

on realQuit()
	do shell script "killall 'applet'"
end realQuit
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
