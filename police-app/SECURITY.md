# Security Policy

## Reporting Security Issues

If you discover a security vulnerability in Rakshak, please report it by emailing the maintainer directly. **Do not create a public GitHub issue.**

---

## API Keys and Secrets

### Google Maps API Key

This project requires a Google Maps API Key for map functionality. 

**⚠️ Important Security Notes:**

1. **Never commit your actual API key to the repository**
2. The config files contain placeholder values: `YOUR_GOOGLE_MAPS_API_KEY_HERE`
3. Add your actual key locally after cloning
4. Restrict your API key in Google Cloud Console:
   - Set application restrictions (Android/iOS bundle IDs)
   - Set API restrictions (only enable required APIs)
   - Set usage quotas to prevent abuse

### AWS API Endpoint

The AWS Lambda endpoint is public and designed for read-only predictions. It does not expose sensitive data or allow write operations.

**Endpoint**: `https://aksdwfbnn5.execute-api.ap-south-1.amazonaws.com/predict`

This endpoint:
- ✅ Accepts POST requests with location data
- ✅ Returns risk predictions (no sensitive data)
- ❌ Does not accept authentication tokens
- ❌ Does not allow data modification
- ❌ Does not expose user information

---

## Best Practices

### For Developers

1. **Never commit secrets**:
   - API keys
   - Private keys
   - Passwords
   - Access tokens
   - Database credentials

2. **Use environment variables**:
   - Copy `.env.example` to `.env`
   - Add your secrets to `.env`
   - `.env` is in `.gitignore` and won't be committed

3. **Rotate compromised keys immediately**:
   - If you accidentally commit a secret, rotate it immediately
   - Delete the secret from Google Cloud Console / AWS
   - Generate a new one
   - Update your local config

4. **Review before pushing**:
   ```bash
   git diff --cached  # Review staged changes
   git log -p -1      # Review last commit
   ```

### For Production Deployment

1. **Use environment-specific keys**:
   - Development keys for local testing
   - Production keys for deployed apps
   - Never use production keys in development

2. **Implement key restrictions**:
   - Google Maps: Restrict by bundle ID and API
   - AWS: Use IAM roles with least privilege
   - Enable CloudWatch monitoring

3. **Monitor usage**:
   - Set up billing alerts
   - Monitor API usage quotas
   - Review access logs regularly

---

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

---

## Security Features

### App Security

- ✅ HTTPS-only communication
- ✅ No local storage of sensitive data
- ✅ Location permissions requested at runtime
- ✅ No third-party analytics tracking
- ✅ Minimal permission requirements

### Backend Security

- ✅ Serverless architecture (AWS Lambda)
- ✅ API Gateway rate limiting
- ✅ No database with user data
- ✅ Stateless ML predictions
- ✅ CORS configured for web dashboard

---

## Acknowledgments

We take security seriously. Thank you for helping keep Rakshak and its users safe!
