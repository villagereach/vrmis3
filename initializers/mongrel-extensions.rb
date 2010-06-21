module Mongrel
  class DirHandler
    def send_file_with_cache_control(req_path, request, response, header_only=false)
      response.header['Cache-Control'] = 'max-age=0, must-revalidate'
      send_file_without_cache_control(req_path, request, response, header_only)
    end
    alias_method_chain :send_file, :cache_control
  end
end
