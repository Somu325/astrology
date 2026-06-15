import logging
import json
import os
import sys
from datetime import datetime, timezone

class JsonFormatter(logging.Formatter):
    """
    Custom logging formatter that outputs logs as structured JSON.
    """
    def format(self, record: logging.LogRecord) -> str:
        log_record = {
            "timestamp": datetime.fromtimestamp(record.created, tz=timezone.utc).isoformat(),
            "level": record.levelname,
            "message": record.getMessage(),
            "logger": record.name,
            "filename": record.filename,
            "lineno": record.lineno,
        }
        
        # Format exception info if present
        if record.exc_info:
            log_record["exception"] = self.formatException(record.exc_info)
        
        # Capture custom properties passed via `extra={...}`
        reserved_attrs = {
            "name", "msg", "args", "levelname", "levelno", "pathname", "filename",
            "module", "exc_info", "exc_text", "stack_info", "lineno", "funcName",
            "created", "msecs", "relativeCreated", "thread", "threadName", "processName", "process"
        }
        extra_keys = set(record.__dict__.keys()) - reserved_attrs
        for key in extra_keys:
            log_record[key] = record.__dict__[key]
            
        return json.dumps(log_record)


def get_logger(name: str) -> logging.Logger:
    """
    Configures and returns a structured logger.
    """
    logger = logging.getLogger(name)
    if logger.hasHandlers():
        return logger
        
    log_level = os.getenv("LOG_LEVEL", "INFO").upper()
    logger.setLevel(log_level)
    
    handler = logging.StreamHandler(sys.stdout)
    
    # Configure formatter based on environment
    json_logging = os.getenv("JSON_LOGGING", "false").lower() in ("true", "1", "yes")
    if json_logging:
        formatter = JsonFormatter()
    else:
        # Standard formatted output for local terminal reading
        formatter = logging.Formatter(
            fmt="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S"
        )
        
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    logger.propagate = False
    
    return logger
