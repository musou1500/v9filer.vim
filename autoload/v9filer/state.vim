vim9script

export def New(root: string, mode: string, prev_buf: number): dict<any>
  return {
    root: root,
    mode: mode,
    show_hidden: get(g:, 'v9filer_show_hidden', true),
    expanded: {},
    line_paths: {},
    help: false,
    prev_buf: prev_buf,
  }
enddef

export def Get(): dict<any>
  return get(b:, 'v9filer_state', {})
enddef

export def Set(st: dict<any>): void
  b:v9filer_state = st
enddef

export def Patch(changes: dict<any>): dict<any>
  var st = Get()
  for [key, value] in items(changes)
    st[key] = value
  endfor
  Set(st)
  return st
enddef
