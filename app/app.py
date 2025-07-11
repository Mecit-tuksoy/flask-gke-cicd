from flask import Flask
import os

app = Flask(__name__)

@app.route('/')
def hello():
    return "Hello from Flask on GKE, v2.0"

@app.route('/health')
def health_check():
    return {"status": "healthy", "service": "flask-app"}, 200

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)