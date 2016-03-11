--------------------------------
Slow Scan Television Demodulator

Author: Jack Bradach

        jack@bradach.net
        
        github.com/jbradach
--------------------------------

This is a Slow Scan Telev- wait, you can look up literally five lines and know
what I'm going to say... Anyway, this project was from another design course at
Portland State University, circa whatever the file timestamps say on them.  The
choice of an SSTV decoder came from my interest in software defined radio.
Unfortunately, it'd be a couple more years before USB SDR radios came down to a
price point where I was willing to jump into.  I probably won't bother going
back now that I have a radio source and interfacing this to it;  much easier
to do in software! :)

The SSTV demod was designed to go on a Digilent "Nexys 3" FPGA platform, which
has a Xilinx Spartan-6 with not nearly enough cells.  I realized after pitching
this idea to the prof that there was not much in the way of existing logic to
talk to the on-board DRAM, which I'd been planning on using as a framebuffer.
I unfortunately know what goes into training and talking to DDR and that was way
too big of a dependency.  Instead, I ended up having to use precious block ram
and limited the resolution and color depth to fit.  It still turned out pretty
cool.  The testbench should show the Portland State University logo and then
draw a second one alongside;  The testbench is actually sending what the ADC
would have handed off to decoder logic.

This code is free to use / modify / whatever.  While you're gonna do what you're
gonna do with it, consider these among options:
- If you use this in your own project, find it useful, etc, drop me a line,
I'd love to know that someone learned from it.
- Don't use this to cheat on your grad school homework.  Seriously, learn
what it's doing and improve upon it.
