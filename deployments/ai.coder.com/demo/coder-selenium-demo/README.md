# Selenium Testing in Coder Workspaces

> [!IMPORTANT]
> This template is centrally managed by CI/CD in the [coder/templates](https://github.com/coder/templates) repository.

This repository demonstrates how to run automated browser testing using Selenium within Coder Workspaces. The workspace comes pre-configured with Selenium Grid, Chrome browser, and all necessary drivers for immediate testing.

## 🚀 Quick Start

Once your Coder Workspace is running, Selenium is automatically available. No additional setup required!

### Test the Setup
```bash
# Quick verification that Selenium is working
./quick-selenium-demo.py

# Check Selenium Grid status
./check-selenium.sh
```

## 📁 Included Test Scripts

### 1. Quick Demo (`quick-selenium-demo.py`)
A fast-running demo that verifies Selenium is working correctly.

```bash
./quick-selenium-demo.py
```

**Features demonstrated:**
- Google search automation
- Multi-site navigation
- JavaScript execution
- Performance metrics capture
- Screenshot generation

### 2. E-commerce Test Suite (`ecommerce-selenium-test.py`)
Real-world testing scenario using a demo e-commerce site.

```bash
./ecommerce-selenium-test.py
```

**Tests included:**
- Homepage loading
- User authentication
- Product search and filtering
- Shopping cart functionality
- Checkout process
- Responsive design testing
- HTML report generation

### 3. Comprehensive Test Suite (`selenium-test-suite.py`)
Eight different test scenarios covering various Selenium capabilities.

```bash
# Run all tests
./selenium-test-suite.py

# Run specific test
./selenium-test-suite.py test_01_google_search
```

**Test cases:**
1. Google search functionality
2. GitHub navigation
3. Form interactions
4. JavaScript execution
5. Screenshot capture
6. Wait conditions
7. Multi-window handling
8. Element attribute inspection

## 🛠️ Technical Details

### Pre-installed Components
- **Selenium Grid**: Running on `http://localhost:4444`
- **Chrome Browser**: Latest stable version (headless-capable)
- **ChromeDriver**: Automatically matched to Chrome version
- **GeckoDriver**: For Firefox support (if needed)
- **Python Selenium**: Pre-configured virtual environment at `/home/coder/selenium-env`

### Architecture
```
┌─────────────────────┐
│   Your Test Code    │
├─────────────────────┤
│  Selenium WebDriver │
├─────────────────────┤
│   Selenium Grid     │
│  (localhost:4444)   │
├─────────────────────┤
│   Chrome Browser    │
│    (Headless)       │
└─────────────────────┘
```

### Available Paths
- **Selenium drivers**: `/home/coder/selenium-drivers/`
- **Python environment**: `/home/coder/selenium-env/`
- **Test screenshots**: `/home/coder/` (persistent storage)
- **Selenium logs**: `/home/coder/selenium.log`

## 💻 Writing Your Own Tests

### Basic Test Template
```python
#!/home/coder/selenium-env/bin/python3
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options

# Configure Chrome options
chrome_options = Options()
chrome_options.add_argument('--headless=new')
chrome_options.add_argument('--no-sandbox')
chrome_options.add_argument('--disable-dev-shm-usage')

# Connect to Selenium Grid
driver = webdriver.Remote(
    command_executor='http://localhost:4444',
    options=chrome_options
)

# Your test code here
driver.get("https://example.com")
print(f"Page title: {driver.title}")

# Cleanup
driver.quit()
```

### Using Different Languages

While the examples are in Python, Selenium Grid supports all major languages:

**Java**
```java
RemoteWebDriver driver = new RemoteWebDriver(
    new URL("http://localhost:4444"), 
    new ChromeOptions()
);
```

**JavaScript**
```javascript
const driver = await new Builder()
    .forBrowser('chrome')
    .usingServer('http://localhost:4444')
    .build();
```

**C#**
```csharp
IWebDriver driver = new RemoteWebDriver(
    new Uri("http://localhost:4444"), 
    new ChromeOptions()
);
```

## 📊 Generated Artifacts

The test scripts generate various artifacts in `/home/coder/`:

- **Screenshots**: `test_*.png`, `demo_*.png`, `selenium-screenshot.png`
- **HTML Reports**: `test_report.html` (from e-commerce tests)
- **Logs**: `selenium.log` (Selenium Grid logs)

## 🔧 Troubleshooting

### Check Selenium Status
```bash
./check-selenium.sh
```

This script shows:
- Chrome version
- ChromeDriver version
- Selenium process status
- Grid connectivity
- Recent log entries

### Common Issues

**Issue**: Tests fail to connect to Selenium Grid
```bash
# Check if Selenium is running
ps aux | grep selenium

# Restart Selenium manually if needed
cd /home/coder/selenium-drivers
java -jar selenium-server.jar standalone &
```

**Issue**: Chrome not found
```bash
# Verify Chrome installation
google-chrome --version

# Check Chrome binary location
which google-chrome
```

**Issue**: Screenshots not saving
```bash
# Ensure write permissions
ls -la /home/coder/

# Check available disk space
df -h /home/coder
```

## 🚀 CI/CD Integration

The headless Chrome setup makes this ideal for CI/CD pipelines:

```yaml
# Example GitHub Actions
- name: Run Selenium Tests
  run: |
    ./selenium-test-suite.py
    ./ecommerce-selenium-test.py
```

```groovy
// Example Jenkins Pipeline
stage('Selenium Tests') {
    steps {
        sh './selenium-test-suite.py'
        sh './ecommerce-selenium-test.py'
    }
}
```

## 📈 Performance Considerations

- **Headless Mode**: All tests run in headless mode for better performance
- **Parallel Testing**: Selenium Grid supports parallel test execution
- **Resource Usage**: Workspace configured with appropriate CPU/memory limits
- **Persistent Storage**: Test artifacts stored in persistent `/home/coder` volume

## 🎯 Use Cases

This Selenium setup in Coder Workspaces is perfect for:

- **QA Teams**: Consistent testing environments for all team members
- **Developers**: Test web applications during development
- **CI/CD**: Automated testing in pipelines
- **Training**: Teaching test automation with pre-configured environments
- **Demos**: Showing testing capabilities to stakeholders

## 📚 Additional Resources

- [Selenium Documentation](https://www.selenium.dev/documentation/)
- [Chrome DevTools Protocol](https://chromedevtools.github.io/devtools-protocol/)
- [Selenium Grid Guide](https://www.selenium.dev/documentation/grid/)
- [Coder Documentation](https://coder.com/docs)

## 🤝 Support

For issues specific to:
- **Selenium**: Check the [Selenium GitHub](https://github.com/SeleniumHQ/selenium)
- **Coder Workspaces**: Visit [Coder Support](https://coder.com/support)
- **Test Scripts**: Modify as needed for your use cases

---

**Happy Testing! 🧪**
