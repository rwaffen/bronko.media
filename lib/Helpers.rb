def index_files(path, extensions)
  files_list = []
  files = []

  extensions.each do |extension|
    # FNM_CASEFOLD is for case insensivity
    files << Dir.glob("#{path}/**/*.#{extension}", File::FNM_CASEFOLD)
  end

  files.flatten.each do |file|
    files_list  << {
      file_path: file,
      folder_path: File.dirname(file),
      image_name: File.basename(file, '.*'),
      md5_path: Digest::MD5.hexdigest(file)
    }
  end

  return files_list
end

def index_folders(path)
  folder_list = []

  Dir.glob("#{path}/**/").each do |folder|
    folder_list << {
      md5_path: Digest::MD5.hexdigest(folder),
      folder_path: folder,
      parent_folder: File.dirname(folder),
      sub_folders: Dir.glob("#{folder}*/")
    }
  end

  return folder_list
end

def write_files_to_db(file_hash)
  file_hash.each do |file|
    Image.find_or_create_by(md5_path: file[:md5_path]) do |image|
      image.file_path   = file[:file_path]
      image.folder_path = file[:folder_path]
      image.image_name  = file[:image_name]
      image.md5_path    = file[:md5_path]
    end
  end
end

def write_folders_to_db(folder_hash)
  folder_hash.each do |folder_path|
    Folder.find_or_create_by(md5_path: folder_path[:md5_path]) do |folder|
      folder.folder_path   = folder_path[:folder_path]
      folder.parent_folder = folder_path[:parent_folder]
      folder.sub_folders   = folder_path[:sub_folders]
      folder.md5_path      = folder_path[:md5_path]
    end
  end
end

def create_thumbs(thumbs_path, size)
  FileUtils.mkdir_p thumbs_path
  Image.all.each do |image|
    image_path = "#{thumbs_path}/#{image.md5_path}.png"

    # only create thumbs if we do not have them already
    unless File.file?(image_path)
      convert = MiniMagick::Tool::Convert.new
      convert << image.file_path # input file
      convert.resize(size)
      convert.gravity('north')
      convert.extent(size)
      convert << image_path # output file
      convert.call
      p "generated: #{image_path}"
    end
  end
end

def remove_file(thumbs_path)
  Image.all.each do |image|
    image_path = image.file_path
    thumb_path = "#{thumbs_path}/#{image.md5_path}.png"
    unless File.file?(image_path)
      p "removing from db: #{image.file_path}"
      image.destroy
      p "removing from fs: #{thumb_path}"
      File.delete(thumb_path)
    end
  end
end

def build_index(image_root, thumbs_path, thumb_size, extensions)
  write_folders_to_db(index_folders(image_root))
  write_files_to_db(index_files(image_root, extensions))
  create_thumbs thumbs_path, thumb_size
  remove_file thumbs_path
end

def flatten_paths_array(paths)
  # https://stackoverflow.com/questions/62741326/ruby-array-of-paths-sort-and-delete-if-included-in-another-item/
  (paths.sort << "").each_cons(2).
    reject { |x,y| y.start_with?(x) }.
    map(&:first)
end