vim9script

export def Normalize(path: string): string
  var normalized = fnamemodify(empty(path) ? getcwd() : path, ':p')
  normalized = substitute(normalized, '/\+$', '', '')
  return empty(normalized) ? '/' : normalized
enddef

export def Join(root: string, name: string): string
  return root ==# '/' ? '/' .. name : root .. '/' .. name
enddef

export def Parent(path: string): string
  var parent = fnamemodify(path, ':h')
  return Normalize(parent)
enddef

export def IsDir(path: string): bool
  return isdirectory(path)
enddef

export def ListDir(root: string, show_hidden: bool): list<dict<any>>
  var entries: list<dict<any>> = []
  var names: list<string>
  try
    names = readdir(root)
  catch
    return entries
  endtry

  for name in names
    if !show_hidden && name =~# '^\.'
      continue
    endif
    var path = Join(root, name)
    var is_dir = isdirectory(path)
    var suffix = is_dir ? '/' : FileSuffix(path)
    add(entries, {
      name: name,
      path: Normalize(path),
      is_dir: is_dir,
      suffix: suffix,
    })
  endfor

  return sort(entries, CompareEntries)
enddef

export def Create(root: string, name: string): void
  if empty(name)
    return
  endif

  var is_dir = name =~# '/$'
  var clean_name = substitute(name, '/\+$', '', '')
  var path = Join(root, clean_name)
  if is_dir
    mkdir(path, 'p')
  else
    writefile([], path, 'b')
  endif
enddef

export def Rename(path: string, new_name: string): void
  if empty(new_name)
    return
  endif
  var target = Join(Parent(path), new_name)
  if rename(path, target) != 0
    echoerr 'v9filer: failed to rename ' .. path
  endif
enddef

export def Delete(path: string): void
  var flags = isdirectory(path) ? 'rf' : ''
  if delete(path, flags) != 0
    echoerr 'v9filer: failed to delete ' .. path
  endif
enddef

export def IsUnder(path: string, root: string): bool
  var normalized_path = Normalize(path)
  var normalized_root = Normalize(root)
  # Match the root itself, descendants with a path-separator boundary, and
  # the filesystem root special case where root .. '/' would become '//'.
  return normalized_path ==# normalized_root
    || stridx(normalized_path, normalized_root .. '/') == 0
    || normalized_root ==# '/' && stridx(normalized_path, '/') == 0
enddef

export def Ancestors(path: string, root: string): list<string>
  var result: list<string> = []
  var current = Parent(path)
  var normalized_root = Normalize(root)
  while IsUnder(current, normalized_root) && current !=# normalized_root
    insert(result, current)
    current = Parent(current)
  endwhile
  if current ==# normalized_root
    insert(result, current)
  endif
  return result
enddef

def FileSuffix(path: string): string
  if getftype(path) ==# 'link'
    return '@'
  endif
  return executable(path) ? '*' : ''
enddef

def CompareEntries(a: dict<any>, b: dict<any>): number
  if a.is_dir && !b.is_dir
    return -1
  endif
  if !a.is_dir && b.is_dir
    return 1
  endif
  return a.name ==# b.name ? 0 : a.name ># b.name ? 1 : -1
enddef
