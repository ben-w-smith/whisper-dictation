# Troubleshooting

Common issues and solutions for DictationApp.

## Recording Issues

### "No audio recorded" Error

**Cause**: Microphone permissions not granted

**Solution**:
1. Run as app bundle, not command line
2. Check System Preferences > Privacy & Security > Microphone
3. Ensure app is signed (or allow in Security settings)

### Recording Starts But No Transcription

**Cause**: Audio device not found or wrong device

**Debug**: Check `/tmp/whisper-dictation/record.log`

**Solution**: Verify `INPUT_DEVICE_INDEX` in `dictate-toggle.py` or let auto-detection work by setting to `None`

### Blank Transcriptions Saved

**Cause**: Audio file too small or no speech detected

**Solution**:
- Check microphone levels in System Preferences
- Speak louder or move closer to microphone
- Use a better quality model (e.g., `base.en` instead of `tiny.en`)

## Performance Issues

### First Transcription is Slow

**Cause**: Model not loaded in memory

**Solution**: App runs `warmup-model.py` on startup. If skipped, first transcription takes 5-10 seconds. The warmup pre-loads the model into memory.

### Transcription Takes Too Long

**Cause**: Large model or long audio

**Solution**:
- Use smaller models (`tiny.en` or `base.en`) for faster transcription
- Break long recordings into shorter segments
- Consider using `distil-large-v3` for balance of speed and accuracy

## Hotkey Issues

### Hotkey Not Working

**Cause**: Recorder not focused in settings

**Solution**: Open Settings > Shortcuts, click the recorder box and press your desired key combination

### Hotkey Conflicts

**Cause**: Another app is using the same hotkey

**Solution**: Change the hotkey in Settings to a different combination

## Permission Issues

### Python Import Errors

**Cause**: Virtual environment not in path

**Solution**: Scripts add venv to path automatically. Verify Python version matches (3.14 in paths). Check that the venv was created:

```bash
cd /Users/bensmith/whisper-dictation
source venv/bin/activate
pip install -r requirements.txt  # if exists
```

### Accessibility Permission for Auto-Paste

**Cause**: Auto-paste requires Accessibility permission

**Solution**:
1. Open System Preferences > Privacy & Security > Accessibility
2. Add DictationApp to the list
3. Restart the app

## Obsidian Integration Issues

### Transcriptions Not Appearing in Vault

**Cause**: Vault path not configured or incorrect

**Solution**:
1. Open Settings > Obsidian
2. Select the correct vault folder
3. Ensure the folder contains a `.obsidian` subfolder

### Cannot Write to Vault

**Cause**: Permission denied

**Solution**:
1. Check folder permissions
2. Ensure the app has Full Disk Access if vault is in a protected location

## AI Refinement Issues

### Refinement Fails

**Cause**: API key invalid or network issue

**Solution**:
1. Verify API key in Settings > Refinement
2. Check network connectivity
3. Check API rate limits

### Refinement Returns Empty

**Cause**: Model response parsing issue

**Solution**: Check the console logs for error messages. The app will fall back to raw transcription.

## Debug Logging

### Python Script Logs

Located at `/tmp/whisper-dictation/record.log`:

```bash
tail -f /tmp/whisper-dictation/record.log
```

### Swift Console Output

Run the app from Xcode or terminal to see debug prints:

```bash
cd /Users/bensmith/whisper-dictation/DictationApp
swift run
```

## Cross-References

- [Recording](features/recording.md) - Audio capture details
- [Auto-Paste](features/auto-paste.md) - Accessibility requirements
- [Obsidian Integration](features/obsidian.md) - Vault configuration
- [Refinement](features/refinement.md) - AI post-processing setup

---

*Last updated: 2026-03-24*
