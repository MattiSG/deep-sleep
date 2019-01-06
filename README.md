# Let your Mac go to hibernation (deep sleep)

Default Mac OS X sleep mode is to prepare hibernation (copy RAM to disk, constant light on) and go to light sleep (pulsing light). On laptops, after 10 to 20% of the battery has been drained in light sleep, the computer will switch to hibernation (longer time to wake up, but no battery drain at all). This behaviour is safe sleep.

It is possible to set the preference to always go to light, deep or safe sleep. However, most of the time safe is okay, except for cases where you know you won't wake your laptop up for at least a couple hours and it would be more energy efficient to go straight to hibernation.

This app aims at making it easy to switch between light (or safe) and deep sleep, by setting a default of light sleep when you close the lid, and going to deep sleep when you start the app.

## Usage

On first start, Deep Sleep will let you define what your default (upon closing lid) and active (upon application start) sleep modes should be. Then, whenever you start it again, it will activate the defined sleep mode.

When waking up from deep sleep, this script will also automatically free the memory used by the hibernate image (the size of your RAM).

Application language is French. Minimum system version is Mac OS X 10.4.3.

## Deprecation notice: targets mostly pre-2011 Macs

This app makes sense for older Mac laptops, that had much less efficient batteries and hard drives instead of SSDs. There is not much use for these different modes nowadays.
An easy way to know if this could be useful for an older Mac is if it has a pulsing sleep light indicator.

## License

MIT
