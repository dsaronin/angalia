# --- angalia_error.rb ---
# Angalia: Custom Exception Definitions
# Copyright (c) 2025 David S Anderson, All Rights Reserved

# Base class for all Angalia-specific exceptions.
# Inherits from StandardError to ensure it's caught by general rescue blocks.

class AngaliaError < StandardError

  # MajorError for critical, unrecoverable configuration issues.
  class MajorError < AngaliaError
    def initialize(msg = "MAJOR configuration error: ")
      super(msg)
    end
  end

  # MinorError for recoverable operational issues.
  class MinorError < AngaliaError
    def initialize(msg = "minor operational error:")
      super(msg)
    end
  end

  # Specific error for when a monitor cannot be found or controlled.
  class MonitorError < MajorError
    def initialize(msg = "Monitor config/control failed.")
      super(msg)
    end
  end

  # Specific error for when monitor operations (turn on/off) fail at runtime.
  class MonitorOperationError < MinorError
    def initialize(msg = "Monitor operation failed.")
      super(msg)
    end
  end


  # Specific error for when webcam configuration or streaming fails.
  class WebcamError < MajorError
    def initialize(msg = "Webcam config/control failed.")
      super(msg)
    end
  end

  # Specific error for when webcam operations (start/stop stream) fail at runtime.
  class WebcamOperationError < MinorError
    def initialize(msg = "Webcam operation failed.")
      super(msg)
    end
  end


  # Specific error for when the Jitsi Meet view (browser) fails to launch or operate.
  class MeetViewError < MajorError
    def initialize(msg = "Jitsi Meet browser failed to launch or operate.")
      super(msg)
    end
  end

  # Specific error for OpenVPN configuration or connection issues.
  class OpenVPNError < MajorError
    def initialize(msg = "OpenVPN connection or configuration failed.")
      super(msg)
    end
  end

  # Custom error for explicitly stopping a livestream thread
  class LivestreamForceStopError < StandardError; end

  # More granular operational errors can be defined here, inheriting from MinorError
  # For example:
  # class OperationError < MinorError
  #   class StreamFailed < OperationError
  #     def initialize(msg = "Webcam stream failed during operation.")
  #       super(msg)
  #     end
  #   end
  #   class DisplayControlFailed < OperationError
  #     def initialize(msg = "Display control failed during operation.")
  #       super(msg)
  #     end
  #   end
  # end


end   # class AngaliaError

