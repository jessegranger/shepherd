

yesNo = (v) -> if v then "yes" else "no"
secs = 1000
mins = 60 * secs
hours = 60 * mins
days = 24 * hours
weeks = 7 * days
formatUptime = (ms) ->
	w = Math.floor(ms / weeks)
	t = ms - (w * weeks)
	d = Math.floor(t / days)
	t = t - (d * days)
	h = Math.floor(t / hours)
	t = t - (h * hours)
	m = Math.floor(t / mins)
	t = t - (m * mins)
	s = Math.floor(t / secs)
	t = t - (s * secs)
	v = $("w d h m s".split " ").weave $ w, d, h, m, s
	d and v.splice(-2, 2) # omit seconds if there are days
	w and v.splice(-2, 2) # omit minutes if there are weeks
	v.join('').replace(/^(0[wdhm])*/,'')

trueFalse = (v) -> if v then true else false

module.exports = { yesNo, formatUptime, trueFalse }
