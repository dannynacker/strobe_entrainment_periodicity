# strobe_entrainment_periodicity_MSc
"assessing the impact of various frequencies between periodic and aperiodic Poisson relative offset jitter flash distributions for the SCCS research strobe on occipital neural entrainment to stroboscopic stimulation"

These files are used to generate 8 5-minute trials randomly selected within a stroboscopic stimulation experiment between 2 different periodicities (periodic and aperiodic Poisson relative offset jitter) at 4 different frequencies (8Hz, 10Hz, 14Hz, and Participant IAF Hz)
through the Sussex Center for Consciousness Science research strobe device. Aperiodic frequencies which differed from their effective frequencies were force-matched through a separate script over a number of iterations and 
entered into a bank to pull participant-specific data during the running of the experimental script. 

It sends triggers at stimulation onset and offset to the eego software specific to a 64-electrode Waveguard gel EEG cap via a parallel port to allow for EEG data epoching of the stimulation period. 
We then isolate the Oz channel in a separate script, epoch the data into trials, submit the data through a preprocessing pipeline, and calculate power through an FFT using EEGLab's pop_fourieeg. 

This repository also contains scripts to calculate participant IAF pre- and post- experimental stimulation through EEGLab and ERPLab. 

EEGLab: https://github.com/sccn/eeglab & 
ERPLab: https://github.com/ucdavis/erplab/releases 

Strobe sequencing scripts to create the flash distributions are thanks to Dr. Lionel Barnett at the Sussex Center for Consciousness Science! 

Future updates will include calculating phase coherence and phase amplitude
between participant Oz channel power and an external photodiode to record strobe-specific data. 

A big thank you to Dr. David Schwartzman, Dr. Lionel Barnett, and Dr. Anil Seth for their guidance through this project as I make headway into the wonderful world of neural engineering. 

for the MSc in Cognitive Neuroscience at the University of Sussex, 2023-2024 
"Investigating the Effects of Neural Entrainment on Stroboscopic Visual Hallucinations"
