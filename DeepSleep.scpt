(*Author : Matti Schneider
*)
property appName : "Deep Sleep"
property theVersion : "2.3ß"
property defaultsFile : "com.mattisg.deepsleep"
property safeList : {0, 1, 3, 5, 7}

init("mattisgdeepsleep", "DeepSleep.icns", "Manuel de Deep Sleep.rtfd")

--Dialogs
property quickSleep : "Veille rapide"
property safeSleep : "Veille sécurisée"
property deepSleep : "Hibernation"
property modesList : {quickSleep, safeSleep, deepSleep}

(*Is the computer a laptop or not ? Moreover, get the current powering mode.*)
global isOnAC
set isLaptop to do shell script "pmset -g | grep -q attery; echo $?"
if translateBool(isLaptop) then
	set isLaptop to true
	set isOnAC to isItOnAC() -- we use the method only here because we don't want to modify the behaviour of the script during its execution, which could happen if the user disconnected his computer during the execution
else
	set isLaptop to false
	set isOnAC to true
end if

(*Manage preferences*)
set hasBeenInitialized to do shell script "ls ~/Library/Preferences/" & defaultsFile & ".plist > /dev/null 2>/dev/null; echo $?" --ls instead of defaults because it is faster
if translateBool(hasBeenInitialized) then
	getPrefs()
	if execIsNotRoot() and not needAuthentification then
		set choice to display dialog "L'exécutable Deep Sleep n'appartient plus au système alors qu'il le devrait. Il est grandement recommandé de réinstaller ce programme, pour plus de sécurité." buttons {"Modifier les droits", "Quitter"} default button 2 with title "ATTENTION" with icon stop
		if choice is {button returned:"Modifier les droits"} then
			setOwner()
		else
			realQuit()
		end if
	end if
else
	checkOSVersion(getOSVersion())
	set choice to display dialog appName & " permet de modifier le mode de veille par défaut, et d'en utiliser un alternatif." & return & "Vous allez à présent configurer les modes de veilles à utiliser." buttons {"Quitter", "Manuel", "Ok"} default button 3 with title appName & " " & theVersion with icon theIcon
	if choice is {button returned:"Ok"} then
		setPrefs()
		setOwner()
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
if shouldCheckForVolumes then
	checkForExternalVolumes()
end if

if needAuthentification then
	do shell script "\"" & execFile & "\" set " & getCode(onLaunchMode) with administrator privileges
else
	do shell script "\"" & execFile & "\" set " & getCode(onLaunchMode)
end if
tell application "System Events"
	sleep
end tell

--following will be executed only when waking from sleep

if needAuthentification then
	do shell script "\"" & execFile & "\" set " & getCode(usualMode) with administrator privileges
	try
		do shell script "\"" & execFile & "\" rm " & getTheVMFile() with administrator privileges
	end try
else
	do shell script "\"" & execFile & "\" set " & getCode(usualMode)
	try
		do shell script "\"" & execFile & "\" rm " & getTheVMFile()
	end try
end if

quit

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

(*INITIALIZATION*)
property theIcon : ""
property descriptionFile : ""
property execFile : ""

on init(executable, icon, manual)
	set theIcon to path to resource icon
	set descriptionFile to path to resource manual
	set execFile to path to resource executable
	set execFile to do shell script "echo '" & (execFile as string) & "' | sed s@:@/@g"
	set execFile to "/Volumes/" & execFile --this one was tricky !
end init

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
	if wasOk then
		if major is 8 then
			return translateBool(do shell script "test " & minor & " -ge 3; echo $?")
		else
			if (major as number) is greater than 8 then
				return true
			else
				display dialog "Version du système non supportée ! Vous devez avoir au moins Mac OS X 10.4.3 pour utiliser la fonction hibernation." buttons {"Quitter"} default button 1 with icon stop
				realQuit()
			end if
		end if
	else
		display dialog "Version du système non supportée ! Vous devez avoir au moins Mac OS X 10.4.3 pour utiliser la fonction hibernation." buttons {"Quitter"} default button 1 with icon stop
		realQuit()
	end if
end checkOSVersion

on isItOnAC()
	set thePowerMode to do shell script "pmset -g | grep '*' | grep -q 'AC'; echo $?" --get current power mode
	return translateBool(thePowerMode)
end isItOnAC

on checkForExternalVolumes()
	tell application "System Events"
		set theList to get the name of every disk
	end tell

	set dialogHasNotBeenShown to true
	set ejectAll to false

	repeat with i from 1 to count of theList
		set theDisk to item i of theList
		set theDiskIsDMG to do shell script "hdiutil info | grep -q '/Volumes/" & theDisk & "'; echo $?" --EjectAll's algorithm
		if theDiskIsDMG is not "0" then
			if dialogHasNotBeenShown then
				set choice to display dialog "Attention : le disque \"" & theDisk & "\" est monté, ne le débranchez pas pendant la veille, vous risqueriez de perdre vos données !" buttons {"Ne plus jamais vérifier", "Ejecter tous les volumes", "OK"} default button 2 with icon caution with title "Volume monté" giving up after 10
				if choice is {button returned:"Ejecter tous les volumes"} then
					set ejectAll to true
				else
					if choice is {button returned:"Ne plus jamais vérifier"} then
						do shell script "defaults write " & defaultsFile & " dontCheckForVolumes -bool TRUE"
					end if
				end if
				set dialogHasNotBeenShown to false
			end if
			if ejectAll then
				ignoring application responses --else it stops everything if one of the elements can't be unmounted
					tell application "Finder"
						eject theDisk
					end tell
				end ignoring
			end if
		end if
	end repeat
end checkForExternalVolumes
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


(*GETTING SYSTEM PREFS FOR HIBERNATION*)
on getEncryptionState()
	try
		set useEncryptedSwap to do shell script "defaults read /Library/Preferences/com.apple.virtualMemory UseEncryptedSwap"
		if translateBool(useEncryptedSwap) then
			return 0 --an int, since the codes are 1 or 3 without encryption and 5 or 7 with it ; therefore, encryptionState is 0 or 4, and we'll calculate the code to use by summing
		else
			return 4
		end if
	on error --that is, the pref file isn't here. This happens if the user hasn't changed the default state…
		if (major as number) is greater than 8 then --…which is true in Leopard (and presumably future systems too) and false in Tiger
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
	set code to -1
	if wantedMode is quickSleep then
		set code to 0
	end if
	if wantedMode is safeSleep then
		set code to (3 + getEncryptionState())
	end if
	if wantedMode is deepSleep then
		set code to (1 + getEncryptionState())
	end if
	if code is in safeList then --just to be sure ;)
		return code
	else
		error --in order to protect the hibernatemode to be corrupted
	end if
end getCode
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


(*MANAGING PREFS AND GETTING USER INPUT*)
property isLaptop : ""
property isOnAC : ""
property shouldCheckForVolumes : ""
property onLaunchMode : ""
property usualMode : ""
property needAuthentification : true

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

	do shell script "defaults write " & defaultsFile & " AC_usualMode '" & chooseFromList("Choisissez le mode de veille à utiliser en temps normal" & AC_parentheses & " :", quickSleep) & "'"
	do shell script "defaults write " & defaultsFile & " AC_onLaunchMode '" & chooseFromList("Choisissez le mode de veille à utiliser en lançant Deep Sleep" & AC_parentheses & " :", deepSleep) & "'"
	if isLaptop then
		do shell script "defaults write " & defaultsFile & " Battery_usualMode '" & chooseFromList("Choisissez le mode de veille à utiliser en temps normal" & Battery_parentheses & " :", quickSleep) & "'"
		do shell script "defaults write " & defaultsFile & " Battery_onLaunchMode '" & chooseFromList("Choisissez le mode de veille à utiliser en lançant Deep Sleep" & Battery_parentheses & " :", deepSleep) & "'"
	end if
	do shell script "defaults write " & defaultsFile & " dontCheckForVolumes -bool FALSE"
end setPrefs

on getPrefs()
	if isOnAC then
		set prefix to "AC_"
	else
		set prefix to "Battery_"
	end if
	try
		set onLaunchMode to do shell script "defaults read " & defaultsFile & " " & prefix & "onLaunchMode"
		set usualMode to do shell script "defaults read " & defaultsFile & " " & prefix & "usualMode"
		set shouldCheckForVolumes to ((do shell script "defaults read " & defaultsFile & " dontCheckForVolumes") is equal to "1")
	on error
		display dialog "Les préférences de " & appName & " sont illisibles. Veuillez choisir à nouveau vos préférences." with icon caution
		setPrefs()
	end try
	try
		set needAuthentification to ((do shell script "defaults read " & defaultsFile & " needAuthentification") is equal to "1")
	on error
		display dialog "Les préférences d'authentification de " & appName & " sont illisibles. Veuillez choisir à nouveau vos préférences." with icon caution
		setOwner()
	end try
end getPrefs
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


(*PASSWORD & CHOWN ISSUES*)
on execIsNotRoot()
	if (translateBool(do shell script "ls -l '" & execFile & "' | grep -q root' '*wheel; echo $?")) then
		return false
	else
		return true
	end if
end execIsNotRoot

on setOwner()
	set choice to display dialog "Souhaitez-vous autoriser " & appName & " à être systématiquement exécuté en tant qu'administrateur ?" & return & "Dans le cas contraire, votre mot de passe vous sera demandé à chaque fois." & return & return & "Votre mot de passe ne sera pas stocké." buttons {"Refuser", "Plus d'infos", "Autoriser"} default button 3 with icon theIcon
	if choice is {button returned:"Plus d'infos"} then
		set choice to display dialog appName & " va vous demander votre mot de passe, pour s'autoriser à modifier le propriétaire du programme. Ainsi, " & appName & " sera identifié comme appartenant au système, et aura systématiquement les droits administrateurs nécessaires pour modifier le mode de veille." buttons {"Refuser", "Autoriser"} default button 2 with icon theIcon
	end if
	do shell script "chmod o+x '" & execFile & "'"
	if choice is {button returned:"Refuser"} then
		do shell script "defaults write " & defaultsFile & " needAuthentification -bool TRUE"
	else
		makeExecFileRoot()
		do shell script "defaults write " & defaultsFile & " needAuthentification -bool FALSE"
	end if
end setOwner

on makeExecFileRoot()
	do shell script "chmod o+x '" & execFile & "'"
	do shell script "sudo chown root:wheel '" & execFile & "'" with administrator privileges
	do shell script "sudo chmod u+s '" & execFile & "'" with administrator privileges
end makeExecFileRoot
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

(*MISCELLANEOUS*)
on translateBool(int)
	if int is "0" then
		return true
	else
		return false
	end if
end translateBool

on realQuit() --Because, for some reason, AppleScript doesn't exit when used "quit" or "quit me" ! I've tried all the workarounds (with a boolean and exiting out of the loops, skipping the main process if we had to quit…), no one works.
	do shell script "killall 'applet'"
end realQuit
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------`ùre
