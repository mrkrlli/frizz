require 'aws-sdk'
require "mime-types"

module Frizz
  class Remote
    def initialize(bucket_name, ignorance, options = {})
      @options = options
      @bucket_name = bucket_name
      @ignorance = ignorance
    end

    def files
      @files ||= objects.reject { |o| ignore?(o) }
    end

    def file_local_path(remote_file_key)
      # since all s3 uploads don't have .gz extension, we need to determine
      # if the local_path should have the .gz extension when comparing local and remote files
      head_object = client.head_object({
        bucket: bucket_name,
        key: remote_file_key
      })

      if head_object.content_encoding == 'gzip'
        "#{remote_file_key}.gz"
      else
        remote_file_key
      end
    end

    def cache_control_changed?(remote_file_key)
      head_object = client.head_object({
        bucket: bucket_name,
        key: remote_file_key
      })

      remote_cache_control_value = head_object.cache_control
      current_cache_control_value = cache_control_option(options, remote_file_key)[:cache_control]

      return remote_cache_control_value != current_cache_control_value
    end

    def upload(file, key, options = {})
      encoding_option = {}

      if options[:prefer_gzip] && key.end_with?('.gz')
        encoding_option[:content_encoding] = 'gzip'

        # remove the '.gz' extension for s3 deploys
        # http://stackoverflow.com/questions/8080824/how-to-serve-gzipped-assets-from-amazon-s3
        key = key.sub(/(.gz)$/, '')
      end

      object_options = {
        bucket: bucket_name,
        body: file,
        acl: 'public-read',
        content_type: MIME::Types.type_for(key).first.content_type,
        key: key
      }
      object_options.merge! encoding_option
      object_options.merge! cache_control_option(options, key)

      object_options[:website_redirect_location] = options[:redirect_to] if options[:redirect_to]

      client.put_object object_options
    end

    def delete(remote_file)
      client.delete_object(
        bucket: bucket_name,
        key: remote_file.key
      )
    end

    private

    attr_reader :bucket_name, :ignorance, :options

    def cache_control_option(options, key)
      cache_control_option_hash = {}
      return cache_control_option_hash unless options[:cache_control]

      mime_type = MIME::Types.type_for(key).first.content_type
      cache_control_value = options[:cache_control][mime_type]

      if cache_control_value
        cache_control_option_hash[:cache_control] = cache_control_value
      end

      cache_control_option_hash
    end

    def ignore?(object)
      # for remote files, you don't need to ignore for gzip preference,
      # since there won't be any gzip files on s3
      ignorance.ignore_matched_pattern?(object.key)
    end

    def objects
      client.list_objects(bucket: bucket_name).contents
    end

    def client
      @client ||= Aws::S3::Client.new(
        region: options[:region],
        credentials: Aws::Credentials.new(
          Frizz.configuration.access_key_id,
          Frizz.configuration.secret_access_key
        )
      )
    end
  end
end
