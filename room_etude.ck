// john eagle, 1.29.19
// electroacoustic etude #1
// 4 corners of b27 recorded three times with:
// Rode NTG4+ (shotgun), AKG C414B (large diaphram), AKG P170 (small diaphram)

// MIDI in setup
MidiIn min;
MidiMsg msg;
// MIDI port
0 => int port;
// open the port
if( !min.open(port) )
{
    <<< "Error: MIDI port did not open on port: ", port >>>;
    me.exit();
}

// this directory
me.dir() + "audio/" => string path;

// filenames
["NTG4_front_left.aif", "NTG4_front_right.aif", "NTG4_back_left.aif", "NTG4_back_right.aif"] @=> string ntg4_filenames[];
["C414B_front_left.aif", "C414B_front_right.aif", "C414B_back_left.aif", "C414B_back_right.aif"] @=> string c414b_filenames[];
["P170_front_left.aif", "P170_front_right.aif", "P170_back_left.aif", "P170_back_right.aif"] @=> string p170_filenames[];

// stereo or quad?
0 => int isQuad; // 0 = stereo 1 = quad

// for quad, each chan to a speaker, for stereo each chan to a pan
4 => int channels;

// construct objects
SndBuf ntg4[channels];
SndBuf c414b[channels];
SndBuf p170[channels];
Envelope envs_ntg4[channels];
Envelope envs_c414b[channels];
Envelope envs_p170[channels];
BPF bpfs[channels];
float filterTargets[channels];
float bends[channels];
float Qtargets[channels];
Pan2 pans[channels];
[-1.0, -0.5, 0.5, 1.0] @=> float panPositions[];


fun void easeFilter( int filterNum )
{
    0.1 => float inc;
    filterTargets[filterNum] => float targetFreq;
    Qtargets[filterNum] => float targetQ;
    while( true ) {
        filterTargets[filterNum] => targetFreq;
        if( bpfs[filterNum].freq() < targetFreq - inc ) {
            bpfs[filterNum].freq() + inc => bpfs[filterNum].freq;
            //<<< "FREQ", targetFreq, bpfs[filterNum].freq() >>>;
        }
        else if( bpfs[filterNum].freq() > targetFreq + inc ) {
            bpfs[filterNum].freq() - inc => bpfs[filterNum].freq;
            //<<< "FREQ", targetFreq, bpfs[filterNum].freq() >>>;
        }
            
        Qtargets[filterNum] => targetQ;
        if( bpfs[filterNum].Q() < targetQ - inc ) {
            bpfs[filterNum].Q() + inc => bpfs[filterNum].Q;
            //<<< "Q", targetQ, bpfs[filterNum].Q() >>>;
        }
        else if( bpfs[filterNum].Q() > targetQ + inc ) {
            bpfs[filterNum].Q() - inc => bpfs[filterNum].Q;
            //<<< "Q", targetQ, bpfs[filterNum].Q() >>>;
        }
        1::ms => now;
    }
}

fun void getMIDI()
{
    float targetFreq;
    float freqBend;
    float targetQ;
    int chan;
    0 => int buffBank;
    // loop
    while( true )
    {
        min => now;
        
        while( min.recv(msg) )
        {
            // print all data
            //<<< msg.data1, msg.data2, msg.data3 >>>;
            
            // change sound buffer bank
            if( msg.data2 == 58 & msg.data3 == 127 & buffBank > 0 )
            {
                1 -=> buffBank;
                <<< buffBank >>>;
            }
            if( msg.data2 == 59 & msg.data3 == 127 & buffBank < 2 )
            {
                1 +=> buffBank;
                <<< buffBank >>>;
            }
            
            // adjust BPF center freq for each channel 
            if( msg.data2 < 4 )
            {
                msg.data2 => chan;
                Std.mtof(msg.data3)/26 + 20 => targetFreq;
                targetFreq => filterTargets[chan];
                <<< "BPF FREQ", chan, targetFreq >>>;
            }
            // adjust fine control (sets bend value only) bend up or down from center of slider range for BPF center 
            if( msg.data2 >= 4 & msg.data2 <= 7 )
            {
                msg.data2 - 4 => chan;
                msg.data3*0.1 - 6.3 => freqBend;
                freqBend => bends[chan];
                <<< "BEND", chan, bends[chan] >>>;
            }
            // add bend value to filter freq
            if( msg.data2 >= 68 & msg.data2 <= 71 )
            {
                msg.data2 - 68 => chan;
                filterTargets[chan] + bends[chan] => filterTargets[chan];
                <<< "BPF FREQ BENT", chan, filterTargets[chan] >>>;
            }
                
            // adjust Q
            if( msg.data2 >= 16 & msg.data2 <= 19 )
            {
                msg.data2 - 16 => chan;
                msg.data3/5 => targetQ;
                targetQ => Qtargets[chan];
                <<< "BPF Q", chan, targetQ >>>;
            }
            // turn channel on
            if( msg.data2 >= 32 & msg.data2 <= 35 )
            {
                msg.data2-32 => chan;
                if( buffBank == 0 ) envs_ntg4[chan].keyOn();
                else if( buffBank == 1 ) envs_c414b[chan].keyOn();
                else if( buffBank == 2 ) envs_p170[chan].keyOn();
                <<< "TURNING ON BANK:", buffBank, "CHANNEL", chan >>>;
            }
            // turn channel off
            if( msg.data2 >= 48 & msg.data2 <= 51 )
            {
                msg.data2-48 => chan;
                if( buffBank == 0 ) envs_ntg4[chan].keyOff();
                else if( buffBank == 1 ) envs_c414b[chan].keyOff();
                else if( buffBank == 2 ) envs_p170[chan].keyOff();
                <<< "TURNING OFF BANK:", buffBank, "CHANNEL", chan >>>;
            }
        }
    }
}

int x;

// setup soundchains
// 0 1
// 2 3

for( 0 => int chan; chan < channels; chan++ )
{
    if( chan == 2 ) 3 => x;
    else if( chan == 3) 2 => x;
    else chan => x;
    
    // route to separate speaker for quad
    if( isQuad )
    {
        <<< x >>>;
        ntg4[x] => envs_ntg4[x] => bpfs[x] => dac.chan(chan);
        c414b[x] => envs_c414b[x] => bpfs[x] => dac.chan(chan);
        p170[x] => envs_p170[x] => bpfs[x] => dac.chan(chan);
    }
    // route to pans for stereo
    else {
        ntg4[x] => envs_ntg4[x] => bpfs[x] => pans[x] => dac;
        c414b[x] => envs_c414b[x] => bpfs[x] => pans[x] => dac;
        p170[x] => envs_p170[x] => bpfs[x] => pans[x] => dac;
        panPositions[chan] => pans[x].pan;
    }
    
    bpfs[x].set(880, 0.1);
    spork ~ easeFilter(x);
    // read in soundfiles
    path + ntg4_filenames[x] => ntg4[x].read;
    path + c414b_filenames[x] => c414b[x].read;
    path + p170_filenames[x] => p170[x].read;
}

// listen for MIDI in
spork ~ getMIDI();

240 => int pieceLength;
now + pieceLength::second => time pieceEnd;

//0.5 => dac.gain;
// loop until piece ends
while( now < pieceEnd )
{
    // reset tapehead to 0 every 10 seconds
    for( 0 => int i; i < channels; i++ )
    {
        0 => ntg4[i].pos;
        0 => c414b[i].pos;
        0 => p170[i].pos;
    }
    10::second => now;
}

<<<"off">>>;
    