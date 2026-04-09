# LibreTranslate API Integration

**Status:** ✅ Configured  
**Date:** 2026-04-08

---

## Overview

This document describes the LibreTranslate API integration for translation services. LibreTranslate is a free and open-source machine translation API that provides text translation between multiple languages.

---

## Configuration

### Environment Variables

The following environment variables are configured in `.env`:

```bash
LIBRETRANSLATE_API_URL=https://libretranslate.cloudigan.net
LIBRETRANSLATE_API_KEY=fbf797730e6dae20f56dfcbbd9064f80
```

**Security Notes:**
- API key is a 32-character hex string
- Key is stored in `.env` (gitignored)
- Never commit the actual key to version control

---

## API Client

### Python Client

A Python client is available at `@/Users/cory/Projects/homelab-nexus/scripts/libretranslate-api-client.py`

**Features:**
- List supported languages
- Detect language of text
- Translate text between languages
- Translate file contents
- Batch translation support
- CLI interface for common operations

### Installation

```bash
cd /Users/cory/Projects/homelab-nexus
pip install -r requirements.txt
```

### Usage Examples

**Test connection:**
```bash
python scripts/libretranslate-api-client.py test-connection
```

**List supported languages:**
```bash
python scripts/libretranslate-api-client.py languages
```

**Detect language:**
```bash
python scripts/libretranslate-api-client.py detect "Bonjour le monde"
```

**Translate text:**
```bash
# Auto-detect source language, translate to English
python scripts/libretranslate-api-client.py translate "Hola mundo" auto en

# Specify source and target languages
python scripts/libretranslate-api-client.py translate "Hello world" en es

# Translate from French to German
python scripts/libretranslate-api-client.py translate "Bonjour" fr de
```

**Translate file:**
```bash
python scripts/libretranslate-api-client.py translate-file document.txt en es
```

---

## API Reference

### Authentication

All API requests require the `api_key` parameter in the request body:

```bash
curl -X POST https://libretranslate.cloudigan.net/translate \
  -H "Content-Type: application/json" \
  -d '{
    "q": "Hello world",
    "source": "en",
    "target": "es",
    "api_key": "your-api-key"
  }'
```

### Endpoints

#### Languages

`POST /languages` - Get list of supported languages

**Response:**
```json
[
  {"code": "en", "name": "English"},
  {"code": "es", "name": "Spanish"},
  {"code": "fr", "name": "French"}
]
```

#### Detect

`POST /detect` - Detect language of text

**Request:**
```json
{
  "q": "Bonjour le monde",
  "api_key": "your-api-key"
}
```

**Response:**
```json
[
  {"confidence": 0.99, "language": "fr"}
]
```

#### Translate

`POST /translate` - Translate text

**Request:**
```json
{
  "q": "Hello world",
  "source": "en",
  "target": "es",
  "format": "text",
  "api_key": "your-api-key"
}
```

**Response:**
```json
{
  "translatedText": "Hola mundo"
}
```

**Parameters:**
- `q` (required) - Text to translate
- `source` (required) - Source language code (use 'auto' for auto-detection)
- `target` (required) - Target language code
- `format` (optional) - 'text' or 'html' (default: 'text')
- `alternatives` (optional) - Number of alternative translations (0-3)
- `api_key` (required) - API key

---

## Supported Languages

Common language codes:
- `en` - English
- `es` - Spanish
- `fr` - French
- `de` - German
- `it` - Italian
- `pt` - Portuguese
- `ru` - Russian
- `zh` - Chinese
- `ja` - Japanese
- `ko` - Korean
- `ar` - Arabic
- `hi` - Hindi

Run `python scripts/libretranslate-api-client.py languages` for the complete list.

---

## Use Cases

### Documentation Translation

**Translate README files:**
```bash
python scripts/libretranslate-api-client.py translate-file README.md en es
```

**Translate documentation:**
```python
from scripts.libretranslate_api_client import LibreTranslateClient

client = LibreTranslateClient()

# Translate documentation to multiple languages
docs = ["Installation Guide", "User Manual", "API Reference"]
for doc in docs:
    spanish = client.translate(doc, 'en', 'es')
    french = client.translate(doc, 'en', 'fr')
    print(f"{doc}:")
    print(f"  ES: {spanish['translatedText']}")
    print(f"  FR: {french['translatedText']}")
```

### Log Translation

**Translate error messages:**
```python
error_msg = "Container failed to start"
translated = client.translate(error_msg, 'en', 'es')
print(translated['translatedText'])
```

### Multi-language Support

**Translate UI strings:**
```python
ui_strings = {
    "welcome": "Welcome to the dashboard",
    "logout": "Logout",
    "settings": "Settings"
}

for key, text in ui_strings.items():
    result = client.translate(text, 'en', 'es')
    print(f"{key}: {result['translatedText']}")
```

---

## Integration with n8n

### Automated Translation Workflows

**Example: Translate incoming webhooks**
```json
{
  "nodes": [
    {
      "name": "Webhook Trigger",
      "type": "n8n-nodes-base.webhook"
    },
    {
      "name": "Translate to English",
      "type": "n8n-nodes-base.httpRequest",
      "parameters": {
        "url": "https://libretranslate.cloudigan.net/translate",
        "method": "POST",
        "sendBody": true,
        "bodyParameters": {
          "q": "={{$json.text}}",
          "source": "auto",
          "target": "en",
          "api_key": "{{$env.LIBRETRANSLATE_API_KEY}}"
        }
      }
    }
  ]
}
```

**Example: Multi-language notification**
```javascript
// n8n workflow to send notifications in multiple languages
const text = "System alert: High CPU usage";
const languages = ['es', 'fr', 'de'];

for (const lang of languages) {
  // Translate
  const response = await fetch('https://libretranslate.cloudigan.net/translate', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({
      q: text,
      source: 'en',
      target: lang,
      api_key: process.env.LIBRETRANSLATE_API_KEY
    })
  });
  
  const result = await response.json();
  // Send notification in target language
  console.log(`${lang}: ${result.translatedText}`);
}
```

---

## Python Library Usage

### Basic Example

```python
from scripts.libretranslate_api_client import LibreTranslateClient

# Initialize client (reads from .env)
client = LibreTranslateClient()

# Translate text
result = client.translate("Hello world", source="en", target="es")
print(result['translatedText'])  # "Hola mundo"

# Auto-detect source language
result = client.translate("Bonjour", source="auto", target="en")
print(result['translatedText'])  # "Hello"

# Detect language
detection = client.detect_language("Ciao mondo")
print(detection[0]['language'])  # "it"
```

### Advanced Example

```python
# Batch translation
texts = [
    "Container deployed successfully",
    "Backup completed",
    "SSL certificate renewed"
]

translations = client.translate_batch(texts, source='en', target='es')
for original, translated in zip(texts, translations):
    print(f"{original} → {translated}")

# Get alternatives
result = client.translate(
    "Hello",
    source="en",
    target="es",
    alternatives=3
)
print(f"Main: {result['translatedText']}")
for i, alt in enumerate(result.get('alternatives', []), 1):
    print(f"Alt {i}: {alt}")

# List all languages
languages = client.get_languages()
for lang in languages:
    print(f"{lang['code']}: {lang['name']}")
```

---

## CLI Quick Reference

```bash
# List supported languages
libretranslate-api-client.py languages

# Detect language
libretranslate-api-client.py detect "Text to detect"

# Translate text
libretranslate-api-client.py translate "Text" [source] [target]

# Examples
libretranslate-api-client.py translate "Hello" en es
libretranslate-api-client.py translate "Bonjour" auto en
libretranslate-api-client.py translate "Hola" es fr

# Translate file
libretranslate-api-client.py translate-file input.txt en es

# Test connection
libretranslate-api-client.py test-connection
```

---

## Integration Opportunities

### With Vikunja

**Translate task descriptions:**
```python
# Get tasks from Vikunja
from scripts.vikunja_api_client import VikunjaClient
from scripts.libretranslate_api_client import LibreTranslateClient

vikunja = VikunjaClient()
translator = LibreTranslateClient()

tasks = vikunja.list_tasks()
for task in tasks:
    if task.get('description'):
        translated = translator.translate(
            task['description'],
            source='auto',
            target='es'
        )
        print(f"{task['title']}: {translated['translatedText']}")
```

### With n8n

**Translate workflow outputs:**
- Translate error messages
- Multi-language notifications
- Translate log entries
- Internationalize alerts

### Documentation

**Translate homelab documentation:**
```bash
# Translate all markdown files to Spanish
for file in documentation/*.md; do
    python scripts/libretranslate-api-client.py translate-file "$file" en es
done
```

---

## Performance Considerations

1. **Rate Limiting**
   - Check LibreTranslate instance limits
   - Implement retry logic for failures
   - Consider caching translations

2. **Batch Processing**
   - Use batch translation for multiple texts
   - Minimize API calls
   - Implement queuing for large jobs

3. **Text Length**
   - LibreTranslate may have character limits
   - Split long texts if needed
   - Consider chunking large documents

---

## Security Considerations

1. **API Key Storage**
   - Stored in `.env` (gitignored)
   - Never commit to version control
   - Rotate periodically

2. **Network Security**
   - API accessed via HTTPS
   - Consider IP whitelisting
   - Monitor API usage

3. **Data Privacy**
   - Translations may contain sensitive data
   - Review what gets translated
   - Consider data retention policies

---

## Troubleshooting

### Connection Issues

```bash
# Test API connectivity
curl -X POST https://libretranslate.cloudigan.net/languages \
  -H "Content-Type: application/json" \
  -d '{"api_key": "your-api-key"}'

# Check environment variables
python -c "import os; from dotenv import load_dotenv; load_dotenv(); print(os.getenv('LIBRETRANSLATE_API_URL'))"
```

### Common Errors

**401/403 Unauthorized:**
- Check API key is correct
- Verify key hasn't been revoked
- Ensure `api_key` is in request body

**400 Bad Request:**
- Verify language codes are valid
- Check text is not empty
- Ensure required parameters are present

**500 Internal Server Error:**
- Check LibreTranslate service status
- Verify text length is within limits
- Try with simpler text

---

## Next Steps

- [ ] Test translation with various languages
- [ ] Create translation cache for common phrases
- [ ] Integrate with documentation workflow
- [ ] Set up automated README translation
- [ ] Create n8n workflow for log translation
- [ ] Document translation best practices

---

## References

- **LibreTranslate GitHub:** https://github.com/LibreTranslate/LibreTranslate
- **API Documentation:** https://libretranslate.com/docs/
- **Supported Languages:** Run `languages` command for current list

---

## Related Documentation

- `@/Users/cory/Projects/homelab-nexus/documentation/N8N-API-INTEGRATION.md` - n8n automation integration
- `@/Users/cory/Projects/homelab-nexus/documentation/VIKUNJA-API-INTEGRATION.md` - Vikunja task management
- `@/Users/cory/Projects/homelab-nexus/scripts/libretranslate-api-client.py` - Python client implementation
