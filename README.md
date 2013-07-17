Phage BM2013 Nordic nRF9E5 radio transciever code.

Transmits "friend" character using shockburst mode ~1 per second, with
some random dithering to prevent collisions. ~50 badges max, 50kbps transmit
speed gives ~10k time slots per second, so chance of collision is small.

Transmits "strobe" character using shockburst mode when button is pressed.
Strobe character is retransmitted (i.e. jamming mode) until button is released.
