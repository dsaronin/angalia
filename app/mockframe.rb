  # ------------------------------------------------------------
  # Mock data for a single, tiny JPEG frame (e.g., a 1x1 black pixel JPEG)
  # This is a base64 encoded string of a very small JPEG.
  # In a real scenario, this would come from the named pipe.
  # ------------------------------------------------------------
  MOCK_JPEG_FRAME_BASE64 = "/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAYEBQYFBAYGBQYHBwYIChAKCgkJChQODwwQFxQYGBcUFhYaHSUfGhsjHBYWICwgIyYnKSopGR8tMC0oMCUoKSj/2wBDAQcHBwoIChMKChMoGhYaKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCj/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAD/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFAEBAAAAAAAAAAAAAAAAAAAAAP/EABQRAQAAAAAAAAAAAAAAAAAAAAD/2gAMAwEAAhEDEQA/AKgAD//Z"
  # ------------------------------------------------------------
  # This method would simulate reading a frame from the pipe.
  # For testing, it just decodes our mock data.
  # Example usage (for testing):
  # frame = webcam_instance.get_mock_webcam_frame
  # puts "Mock frame length: #{frame.length} bytes"
  # puts "Mock frame encoding: #{frame.encoding}"
 
