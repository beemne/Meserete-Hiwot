import wave
import struct
import math
import os

def generate_chime_alarm(filename, duration_sec=4.0, sample_rate=44100):
    # Generates a clear, resonant, melodic chime alarm sound
    # Harmonic frequencies resembling a church bell chime (A minor/major resonant chords)
    # Notes: A4 (440Hz), C#5 (554.37Hz), E5 (659.25Hz), A5 (880Hz)
    
    num_samples = int(duration_sec * sample_rate)
    
    # Chime sequence: 4 distinct chime strikes in sequence (0.0s, 0.9s, 1.8s, 2.7s)
    strikes = [
        (0.0, [440.0, 880.0, 1320.0, 1760.0]),
        (0.8, [554.37, 1108.73, 1663.1]),
        (1.6, [659.25, 1318.5, 1977.75]),
        (2.4, [880.0, 1760.0, 2640.0, 3520.0])
    ]
    
    samples = [0.0] * num_samples
    
    for start_time, freqs in strikes:
        start_idx = int(start_time * sample_rate)
        strike_len = int(1.4 * sample_rate)
        for i in range(strike_len):
            idx = start_idx + i
            if idx >= num_samples:
                break
            t = i / sample_rate
            # Sharp attack, smooth exponential decay
            envelope = math.exp(-3.2 * t)
            val = 0.0
            for h_idx, f in enumerate(freqs):
                harmonic_weight = 1.0 / (h_idx + 1)
                val += harmonic_weight * math.sin(2.0 * math.pi * f * t)
            samples[idx] += val * envelope
            
    # Normalize
    max_val = max(abs(s) for s in samples) or 1.0
    scale = 28000.0 / max_val
    
    os.makedirs(os.path.dirname(os.path.abspath(filename)), exist_ok=True)
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(2) # Stereo
        wav_file.setsampwidth(2) # 16-bit
        wav_file.setframerate(sample_rate)
        
        frames = bytearray()
        for s in samples:
            int_val = int(s * scale)
            int_val = max(-32767, min(32767, int_val))
            packed = struct.pack('<hh', int_val, int_val)
            frames.extend(packed)
        wav_file.writeframes(frames)
    print(f"Generated {filename} ({num_samples} samples, {duration_sec}s)")

if __name__ == '__main__':
    raw_path = r'c:\Users\HP\Documents\MH-app-1.5.3\mobile\mobile\android\app\src\main\res\raw\alarm.wav'
    asset_path = r'c:\Users\HP\Documents\MH-app-1.5.3\mobile\mobile\assets\audio\alarm.wav'
    generate_chime_alarm(raw_path)
    generate_chime_alarm(asset_path)
