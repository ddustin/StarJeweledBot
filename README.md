StarJewledBot
=============

Blizzard made an exclusive Portrait in Starcraft that you can only get by beating Starjeweled in a difficult manner. This bot beats the game perfectly so you can get that portrait.

* Turn our system sound all the way down (but don't mute it).
* Run the application in XCode.
* Run Starcraft in Fullscreen (Windowed) mode.
* Put the mouse in the exact upper left corner pixel of the Bewjeweled screen.
* Increase your system volume. The louder your volume the faster the bot will play.
* The mouse will still work, allowing you to cast the heal spell (required to get the portrait).

If you have a faster computer, increase the value of amnt in AppDelegate.m:187 from 20 to 50. This will greatly increase the accuracy of the bot and get you a higher score.

When the program is running, a window will appear. Once the bot is started, what the bot sees on the jewel board will be displayed in the window. This is useful to debug issues and see if you need to increase the amnt value mentioned above.

The bot uses a recursive algorithm to for the outcome of every possible move. The move that produces the highest score is chosen -- you will often see moves that create 3 to 4 combos. In some cases the combos are 6 or larger.

Here are the achievements you can unlock in Starjewled: http://starcraft.wikia.com/wiki/Ornatus

Here's a video of someone getting it the hard way:
http://www.youtube.com/watch?v=LtMOZwc32EI

Here is the bot in action:

<img src="https://raw.githubusercontent.com/ddustin/StarJeweledBot/master/StarJeweledBot/2.png"/>
