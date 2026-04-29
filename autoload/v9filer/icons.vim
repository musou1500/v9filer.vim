vim9script

const NerdFontBuiltinRules: list<dict<any>> = [
  {text: '󰡨 ', color: '#2496ED', when: {name_pattern: '\v^(\.dockerignore|\.Dockerignore)$'}},
  {text: ' ', color: '#019833', when: {name_pattern: '^\.vimrc$'}},
  {text: '󰡨 ', color: '#2496ED', when: {name_pattern: '^Dockerfile$'}},
  {text: ' ', color: '#427819', when: {name_pattern: '\v^(Makefile|GNUmakefile)$'}},
  {text: ' ', color: '#89E051', when: {name_pattern: glob2regpat('*.bash')}},
  {text: ' ', color: '#599EFF', when: {name_pattern: glob2regpat('*.c')}},
  {text: ' ', color: '#6D8086', when: {name_pattern: glob2regpat('*.conf')}},
  {text: ' ', color: '#F34B7D', when: {name_pattern: glob2regpat('*.cpp')}},
  {text: ' ', color: '#1572B6', when: {name_pattern: glob2regpat('*.css')}},
  {text: ' ', color: '#EBCB8B', when: {name_pattern: glob2regpat('*.diff')}},
  {text: ' ', color: '#00ADD8', when: {name_pattern: glob2regpat('*.go')}},
  {text: ' ', color: '#A8B9CC', when: {name_pattern: glob2regpat('*.h')}},
  {text: ' ', color: '#A8B9CC', when: {name_pattern: glob2regpat('*.hpp')}},
  {text: ' ', color: '#E34C26', when: {name_pattern: glob2regpat('*.html')}},
  {text: ' ', color: '#F1E05A', when: {name_pattern: glob2regpat('*.js')}},
  {text: ' ', color: '#CBCB41', when: {name_pattern: glob2regpat('*.json')}},
  {text: ' ', color: '#61DAFB', when: {name_pattern: glob2regpat('*.jsx')}},
  {text: ' ', color: '#BBBBBB', when: {name_pattern: glob2regpat('*.lock')}},
  {text: ' ', color: '#51A0CF', when: {name_pattern: glob2regpat('*.lua')}},
  {text: '󰍔 ', color: '#519ABA', when: {name_pattern: glob2regpat('*.md')}},
  {text: ' ', color: '#3572A5', when: {name_pattern: glob2regpat('*.py')}},
  {text: ' ', color: '#DEA584', when: {name_pattern: glob2regpat('*.rs')}},
  {text: ' ', color: '#89E051', when: {name_pattern: glob2regpat('*.sh')}},
  {text: ' ', color: '#9C4221', when: {name_pattern: glob2regpat('*.toml')}},
  {text: ' ', color: '#3178C6', when: {name_pattern: glob2regpat('*.ts')}},
  {text: ' ', color: '#3178C6', when: {name_pattern: glob2regpat('*.tsx')}},
  {text: '󰈙 ', color: '#A6ACCD', when: {name_pattern: glob2regpat('*.txt')}},
  {text: ' ', color: '#019833', when: {name_pattern: glob2regpat('*.vim')}},
  {text: '󰗀 ', color: '#E37933', when: {name_pattern: glob2regpat('*.xml')}},
  {text: ' ', color: '#CB171E', when: {name_pattern: glob2regpat('*.yaml')}},
  {text: ' ', color: '#CB171E', when: {name_pattern: glob2regpat('*.yml')}},
  {text: ' ', color: '#E0AF68', when: {name_pattern: glob2regpat('*.zip')}},
]

const NerdFontTypeFallbacks: dict<dict<string>> = {
  directory: {text: ' ', color: '#7EB7E6'},
  symlink: {text: ' ', color: '#D08770'},
  executable: {text: ' ', color: '#89E051'},
  file: {text: ' ', color: '#C0C0C0'},
}

export def IconForEntry(entry: dict<any>): dict<string>
  var facts = EntryFacts(entry)
  var user_rules = get(g:, 'v9filer_nerd_font_icon_rules', [])
  var rule = MatchingIconRule(facts, user_rules)
  if empty(rule)
    rule = MatchingIconRule(facts, NerdFontBuiltinRules)
  endif

  if !empty(rule)
    return IconResult(RuleText(rule), RuleColor(rule), entry)
  endif

  var fallback = FallbackIcon(entry)
  return IconResult(fallback.text, fallback.color, entry)
enddef

export def IsIconColor(color: string): bool
  return color =~# '^#[0-9A-Fa-f]\{6}$'
enddef

export def IconsEnabled(): bool
  var config: any = get(g:, 'v9filer_nerd_font_icons', false)
  if type(config) == v:t_bool || type(config) == v:t_number
    return config ? true : false
  endif
  return false
enddef

def MatchingIconRule(facts: dict<any>, rules: list<any>): dict<any>
  for rule in rules
    if type(rule) == v:t_dict
        && RuleHasText(rule)
        && RuleMatches(facts, get(rule, 'when', {}))
      return rule
    endif
  endfor
  return {}
enddef

def IconResult(text: string, color: string, entry: dict<any>): dict<string>
  return {text: text, color: color, group: IconGroup(entry)}
enddef

def RuleText(rule: dict<any>): string
  var text: any = get(rule, 'text', '')
  return type(text) == v:t_string ? text : ''
enddef

def RuleColor(rule: dict<any>): string
  var color: any = get(rule, 'color', '')
  return type(color) == v:t_string ? color : ''
enddef

def RuleHasText(rule: dict<any>): bool
  return type(get(rule, 'text', '')) == v:t_string
enddef

def EntryFacts(entry: dict<any>): dict<any>
  var name = get(entry, 'name', '')
  return {
    name: name,
    is_dir: get(entry, 'is_dir', false) ? true : false,
    is_symlink: get(entry, 'is_symlink', false) ? true : false,
    is_executable: get(entry, 'is_executable', false) ? true : false,
  }
enddef

def RuleMatches(facts: dict<any>, when: any): bool
  if type(when) != v:t_dict
    return false
  endif

  var conditions: dict<any> = when
  var matched_keys = 0

  if has_key(conditions, 'name_pattern')
    matched_keys += 1
    if type(conditions.name_pattern) != v:t_string
        || !StringMatchesPattern(facts.name, conditions.name_pattern)
      return false
    endif
  endif
  if has_key(conditions, 'is_dir')
    matched_keys += 1
    if !BoolFactMatches(facts.is_dir, conditions.is_dir)
      return false
    endif
  endif
  if has_key(conditions, 'is_symlink')
    matched_keys += 1
    if !BoolFactMatches(facts.is_symlink, conditions.is_symlink)
      return false
    endif
  endif
  if has_key(conditions, 'is_executable')
    matched_keys += 1
    if !BoolFactMatches(facts.is_executable, conditions.is_executable)
      return false
    endif
  endif
  return matched_keys == len(conditions)
enddef

def BoolFactMatches(actual: bool, expected: any): bool
  if type(expected) != v:t_bool && type(expected) != v:t_number
    return false
  endif
  return actual == (expected ? true : false)
enddef

def StringMatchesPattern(value: string, pattern: string): bool
  try
    return value =~# pattern
  catch
    return false
  endtry
enddef

def IconGroup(entry: dict<any>): string
  if entry.is_dir
    return 'V9FilerIconDirectory'
  endif
  if get(entry, 'is_symlink', false)
    return 'V9FilerIconSymlink'
  endif
  if get(entry, 'is_executable', false)
    return 'V9FilerIconExecutable'
  endif
  return 'V9FilerIconFile'
enddef

def FallbackIcon(entry: dict<any>): dict<string>
  if entry.is_dir
    return NerdFontTypeFallbacks.directory
  endif
  if get(entry, 'is_symlink', false)
    return NerdFontTypeFallbacks.symlink
  endif
  if get(entry, 'is_executable', false)
    return NerdFontTypeFallbacks.executable
  endif
  return NerdFontTypeFallbacks.file
enddef
