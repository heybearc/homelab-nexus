#!/usr/bin/env python3
"""
LibreTranslate API Client for Translation Services
Provides utilities to translate text between languages using LibreTranslate.
"""

import os
import sys
import json
import requests
from typing import Dict, List, Optional
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

class LibreTranslateClient:
    """Client for interacting with LibreTranslate API"""
    
    def __init__(self):
        self.api_url = os.getenv('LIBRETRANSLATE_API_URL', 'https://libretranslate.cloudigan.net')
        self.api_key = os.getenv('LIBRETRANSLATE_API_KEY')
        
        if not self.api_key:
            raise ValueError("LIBRETRANSLATE_API_KEY not found in environment variables")
        
        self.headers = {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }
    
    def _request(self, endpoint: str, data: Optional[Dict] = None) -> Dict:
        """Make API request to LibreTranslate"""
        url = f"{self.api_url}/{endpoint.lstrip('/')}"
        
        # Add API key to request data
        if data is None:
            data = {}
        data['api_key'] = self.api_key
        
        try:
            response = requests.post(url, headers=self.headers, json=data)
            response.raise_for_status()
            return response.json()
        
        except requests.exceptions.RequestException as e:
            print(f"❌ API request failed: {e}")
            if hasattr(e, 'response') and e.response is not None:
                print(f"Response: {e.response.text}")
            sys.exit(1)
    
    def get_languages(self) -> List[Dict]:
        """Get list of supported languages"""
        return self._request('languages')
    
    def detect_language(self, text: str) -> List[Dict]:
        """Detect the language of given text"""
        data = {'q': text}
        return self._request('detect', data)
    
    def translate(
        self, 
        text: str, 
        source: str = 'auto', 
        target: str = 'en',
        format: str = 'text',
        alternatives: int = 0
    ) -> Dict:
        """
        Translate text from source language to target language
        
        Args:
            text: Text to translate
            source: Source language code (use 'auto' for auto-detection)
            target: Target language code
            format: 'text' or 'html'
            alternatives: Number of alternative translations (0-3)
        
        Returns:
            Dict with 'translatedText' and optionally 'alternatives'
        """
        data = {
            'q': text,
            'source': source,
            'target': target,
            'format': format
        }
        
        if alternatives > 0:
            data['alternatives'] = min(alternatives, 3)
        
        return self._request('translate', data)
    
    def translate_batch(
        self,
        texts: List[str],
        source: str = 'auto',
        target: str = 'en'
    ) -> List[str]:
        """
        Translate multiple texts at once
        
        Args:
            texts: List of texts to translate
            source: Source language code
            target: Target language code
        
        Returns:
            List of translated texts
        """
        results = []
        for text in texts:
            result = self.translate(text, source, target)
            results.append(result.get('translatedText', ''))
        return results
    
    def get_language_name(self, code: str) -> str:
        """Get language name from language code"""
        languages = self.get_languages()
        for lang in languages:
            if lang.get('code') == code:
                return lang.get('name', code)
        return code


def main():
    """CLI interface for LibreTranslate API client"""
    if len(sys.argv) < 2:
        print("Usage: libretranslate-api-client.py <command> [args]")
        print("\nCommands:")
        print("  languages                           - List supported languages")
        print("  detect <text>                       - Detect language of text")
        print("  translate <text> [source] [target]  - Translate text")
        print("  translate-file <file> [source] [target] - Translate file contents")
        print("  test-connection                     - Test API connection")
        print("\nExamples:")
        print("  libretranslate-api-client.py translate 'Hello world' en es")
        print("  libretranslate-api-client.py translate 'Bonjour' auto en")
        print("  libretranslate-api-client.py detect 'Hola mundo'")
        sys.exit(1)
    
    command = sys.argv[1]
    client = LibreTranslateClient()
    
    try:
        if command == 'languages':
            languages = client.get_languages()
            print(f"✅ Supported languages ({len(languages)}):")
            for lang in sorted(languages, key=lambda x: x.get('name', '')):
                code = lang.get('code', 'N/A')
                name = lang.get('name', 'Unknown')
                print(f"  {code:5} - {name}")
        
        elif command == 'detect':
            if len(sys.argv) < 3:
                print("❌ Error: Text required")
                sys.exit(1)
            text = ' '.join(sys.argv[2:])
            results = client.detect_language(text)
            print(f"✅ Language detection for: '{text}'")
            for result in results:
                lang_code = result.get('language', 'unknown')
                confidence = result.get('confidence', 0) * 100
                lang_name = client.get_language_name(lang_code)
                print(f"  {lang_name} ({lang_code}): {confidence:.1f}% confidence")
        
        elif command == 'translate':
            if len(sys.argv) < 3:
                print("❌ Error: Text required")
                sys.exit(1)
            
            text = sys.argv[2]
            source = sys.argv[3] if len(sys.argv) > 3 else 'auto'
            target = sys.argv[4] if len(sys.argv) > 4 else 'en'
            
            result = client.translate(text, source, target)
            translated = result.get('translatedText', '')
            
            source_name = client.get_language_name(source) if source != 'auto' else 'Auto-detect'
            target_name = client.get_language_name(target)
            
            print(f"✅ Translation ({source_name} → {target_name}):")
            print(f"  Original:   {text}")
            print(f"  Translated: {translated}")
            
            # Show alternatives if available
            if 'alternatives' in result:
                print(f"\n  Alternatives:")
                for i, alt in enumerate(result['alternatives'], 1):
                    print(f"    {i}. {alt}")
        
        elif command == 'translate-file':
            if len(sys.argv) < 3:
                print("❌ Error: File path required")
                sys.exit(1)
            
            file_path = sys.argv[2]
            source = sys.argv[3] if len(sys.argv) > 3 else 'auto'
            target = sys.argv[4] if len(sys.argv) > 4 else 'en'
            
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    text = f.read()
                
                result = client.translate(text, source, target)
                translated = result.get('translatedText', '')
                
                output_file = f"{file_path}.{target}.txt"
                with open(output_file, 'w', encoding='utf-8') as f:
                    f.write(translated)
                
                print(f"✅ File translated successfully!")
                print(f"  Input:  {file_path}")
                print(f"  Output: {output_file}")
                print(f"  {source} → {target}")
            
            except FileNotFoundError:
                print(f"❌ Error: File not found: {file_path}")
                sys.exit(1)
            except Exception as e:
                print(f"❌ Error reading/writing file: {e}")
                sys.exit(1)
        
        elif command == 'test-connection':
            languages = client.get_languages()
            test_result = client.translate("Hello", "en", "es")
            print(f"✅ Connection successful!")
            print(f"   Supported languages: {len(languages)}")
            print(f"   Test translation: 'Hello' → '{test_result.get('translatedText')}'")
        
        else:
            print(f"❌ Unknown command: {command}")
            sys.exit(1)
    
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
