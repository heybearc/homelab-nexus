/**
 * M365 OAuth2 Email Sender
 * Uses Microsoft Graph API with OAuth2 client credentials flow
 */

const https = require('https');

class M365OAuthMailer {
  constructor(config) {
    this.clientId = config.clientId;
    this.tenantId = config.tenantId;
    this.clientSecret = config.clientSecret;
    this.fromEmail = config.fromEmail;
    this.fromName = config.fromName || 'Cloudigan IT Solutions';
    
    this.tokenEndpoint = `https://login.microsoftonline.com/${this.tenantId}/oauth2/v2.0/token`;
    this.graphEndpoint = `https://graph.microsoft.com/v1.0/users/${this.fromEmail}/sendMail`;
    
    this.accessToken = null;
    this.tokenExpiry = null;
  }

  /**
   * Get OAuth2 access token using client credentials flow
   */
  async getAccessToken() {
    // Return cached token if still valid
    if (this.accessToken && this.tokenExpiry && Date.now() < this.tokenExpiry) {
      return this.accessToken;
    }

    return new Promise((resolve, reject) => {
      const postData = new URLSearchParams({
        client_id: this.clientId,
        client_secret: this.clientSecret,
        scope: 'https://graph.microsoft.com/.default',
        grant_type: 'client_credentials'
      }).toString();

      const options = {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Content-Length': Buffer.byteLength(postData)
        }
      };

      const req = https.request(this.tokenEndpoint, options, (res) => {
        let data = '';
        res.on('data', (chunk) => data += chunk);
        res.on('end', () => {
          if (res.statusCode === 200) {
            const response = JSON.parse(data);
            this.accessToken = response.access_token;
            // Set expiry with 5 minute buffer
            this.tokenExpiry = Date.now() + ((response.expires_in - 300) * 1000);
            resolve(this.accessToken);
          } else {
            reject(new Error(`Token request failed: ${res.statusCode} ${data}`));
          }
        });
      });

      req.on('error', reject);
      req.write(postData);
      req.end();
    });
  }

  /**
   * Send email via Microsoft Graph API
   * @param {Object} options - Email options
   * @param {string} options.to - Recipient email address
   * @param {string} options.subject - Email subject
   * @param {string} options.html - HTML email body
   * @param {string} options.text - Plain text email body (optional)
   */
  async sendMail(options) {
    try {
      const token = await this.getAccessToken();

      const emailMessage = {
        message: {
          subject: options.subject,
          body: {
            contentType: options.html ? 'HTML' : 'Text',
            content: options.html || options.text
          },
          toRecipients: [
            {
              emailAddress: {
                address: options.to
              }
            }
          ],
          from: {
            emailAddress: {
              address: this.fromEmail,
              name: this.fromName
            }
          }
        },
        saveToSentItems: true
      };

      return new Promise((resolve, reject) => {
        const postData = JSON.stringify(emailMessage);

        const options = {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(postData)
          }
        };

        const req = https.request(this.graphEndpoint, options, (res) => {
          let data = '';
          res.on('data', (chunk) => data += chunk);
          res.on('end', () => {
            if (res.statusCode === 202 || res.statusCode === 200) {
              resolve({ success: true, messageId: res.headers['request-id'] });
            } else {
              reject(new Error(`Email send failed: ${res.statusCode} ${data}`));
            }
          });
        });

        req.on('error', reject);
        req.write(postData);
        req.end();
      });
    } catch (error) {
      throw new Error(`M365 OAuth email failed: ${error.message}`);
    }
  }
}

module.exports = M365OAuthMailer;
