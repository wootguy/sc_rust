# Rust for Sven Co-op
These are the scripts used in the [Rust maps](http://scmapdb.com/map:rust) for Sven Co-op. These scripts depend on [weapon_custom](https://github.com/wootguy/weapon_custom) to function.

# Installation
1. Click "Clone or download" then "Download Zip"
1. Extract the files inside "sc_rust-master" into your "svencoop_downloads/scripts/maps/rust/" folder

# Adding guitar songs
copy-paste patterns from OpenMPT into a .txt file. These commands let you choose which channels to use, and add an octave offset per channel. Only 4 channels can play at the same time.  
https://github.com/wootguy/sc_rust/blob/master/guitar_songs/greenhill.txt#L1C1-L2C14  
the !loop command sets the loop point when the end of the file is reached  
https://github.com/wootguy/sc_rust/blob/master/guitar_songs/greenhill.txt#L152  
add your .txt to the menu here. The number after the title is the playback speed.  
https://github.com/wootguy/sc_rust/blob/master/guitar.as#L3 
