import os

bind = f"0.0.0.0:{os.getenv('PORT', '8080')}"
workers = 1
timeout = 300
max_requests = 1000
preload_app = True
