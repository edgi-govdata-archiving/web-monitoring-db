desc 'Rename a site that pages are attached to.'
task :rename_site, [:old_name, :new_name] => [:environment] do |_t, args|
  old_pages = Page.where(site: args[:old_name]).to_a
  new_pages = Page.where(site: args[:new_name]).to_a

  renamable_ids = []
  merged = 0
  old_pages.each do |page|
    merge_target = new_pages.find {|new_page| new_page.url == page.url}
    if merge_target
      merge_pages(page, merge_target)
      merged += 1
    else
      renamable_ids << page.uuid
    end
  end

  renamed = Page.where(uuid: renamable_ids).update_all(site: args[:new_name])

  puts "Renamed site on #{renamed} pages."
  puts "Merged #{merged} pages."
end

def merge_pages(old_page, new_page)
  old_page.versions.update_all(page_uuid: new_page.uuid)

  if old_page.created_at < new_page.created_at
    new_page.update(created_at: old_page.created_at)
  end

  old_page.destroy
end
