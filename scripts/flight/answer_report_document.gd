extends RefCounted
## Builds a self-contained UTF-8 HTML document for browser printing / Save as PDF.

const REPORT_FONT: FontFile = preload("res://assets/paperglide/fonts/NotoSans-Cyrillic.subset.woff2")
const REPORT_FONT_FAMILY := "Paper Glide Noto"


static func build_document(context: Dictionary, entries: Array[Dictionary], labels: Dictionary) -> String:
	var document := PackedStringArray()
	var report_title := _escape_html(str(labels.get("report_title", "Paper Glide - Flight Answer Review")))
	document.append("<!doctype html>")
	document.append("<html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">")
	document.append("<title>%s</title>" % report_title)
	var font_source := "data:font/woff2;base64," + Marshalls.raw_to_base64(REPORT_FONT.data)
	document.append("<style>@font-face{font-family:'%s';src:url('%s') format('woff2');font-style:normal;font-weight:400;font-display:block;}</style>" % [REPORT_FONT_FAMILY, font_source])
	document.append("""<style>
		:root { color-scheme: light; --ink:#292a31; --paper:#f6f1e2; --card:#fffdf6; --blue:#4d78bd; --red:#bd4b43; --green:#557b49; }
		* { box-sizing:border-box; }
		body { margin:0; padding:28px; color:var(--ink); background:var(--paper); font:16px/1.5 "Paper Glide Noto", Arial, sans-serif; }
		main { max-width:900px; margin:0 auto; }
		header { border-bottom:3px solid var(--ink); padding-bottom:16px; margin-bottom:20px; }
		h1 { margin:0 0 5px; font-size:30px; line-height:1.2; }
		.summary { margin:8px 0 3px; font-weight:700; }
		.date { margin:0; color:#5d5e64; font-size:14px; }
		.instructions { margin:12px 0 0; padding:10px 12px; background:#e8eef8; border-left:4px solid var(--blue); }
		.toolbar { margin:0 0 18px; text-align:right; }
		button { padding:10px 18px; border:2px solid var(--ink); border-radius:8px; background:#dbe7f8; color:var(--ink); font-weight:700; font-size:15px; cursor:pointer; }
		.entry { margin:0 0 14px; padding:15px 17px; background:var(--card); border:1px solid #b8b5ac; border-left:5px solid var(--blue); border-radius:7px; break-inside:avoid; page-break-inside:avoid; }
		.entry.correct { border-left-color:var(--green); }
		.entry.incorrect { border-left-color:var(--red); }
		.entry.unanswered { border-left-color:var(--blue); }
		.entry-head { display:flex; justify-content:space-between; align-items:flex-start; gap:14px; margin-bottom:9px; }
		.entry-head h2 { margin:0; font-size:18px; }
		.status { font-size:12px; font-weight:700; white-space:nowrap; }
		.status.correct { color:var(--green); }
		.status.incorrect { color:var(--red); }
		.status.unanswered { color:var(--blue); }
		.question { margin:0 0 12px; font-size:18px; font-weight:600; overflow-wrap:anywhere; }
		.answers { display:grid; grid-template-columns:1fr 1fr; gap:12px; }
		.answer { padding:9px 11px; background:#f6f4ed; border-radius:5px; overflow-wrap:anywhere; }
		.answer strong { display:block; font-size:12px; text-transform:uppercase; letter-spacing:.04em; margin-bottom:3px; }
		.gate-note { margin:9px 0 0; color:#55565c; font-size:13px; }
		.empty { padding:18px; background:var(--card); border:1px dashed #999; }
		footer { margin-top:22px; padding-top:10px; border-top:1px solid #b8b5ac; color:#666; font-size:12px; }
		@media (max-width:600px) { body { padding:16px; } .entry-head { display:block; } .status { display:block; margin-top:4px; } .answers { grid-template-columns:1fr; } }
		@page { size:A4; margin:14mm; }
		@media print { body { padding:0; background:#fff; } .toolbar { display:none; } header { margin-bottom:14px; } .entry { background:#fff; } }
	</style></head><body><main>""")
	document.append("<div class=\"toolbar\"><button type=\"button\" onclick=\"window.print()\">%s</button></div>" % _escape_html(str(labels.get("print_button", "Print / Save as PDF"))))
	document.append("<header><h1>%s</h1><p class=\"summary\">%s</p><p class=\"date\">%s: %s</p><p class=\"instructions\">%s</p></header>" % [
		report_title,
		_escape_html(str(context.get("summary", ""))),
		_escape_html(str(labels.get("date_label", "Flight ended"))),
		_escape_html(str(context.get("date", ""))),
		_escape_html(str(labels.get("print_instructions", "Choose Save as PDF in the print dialog to download a copy."))),
	])
	if entries.is_empty():
		document.append("<p class=\"empty\">%s</p>" % _escape_html(str(labels.get("empty", "No questions were recorded on this flight."))))
	else:
		for entry: Dictionary in entries:
			var status := str(entry.get("status", "unanswered"))
			if status not in ["correct", "incorrect", "unanswered"]:
				status = "unanswered"
			var selected_answer := str(entry.get("selected_answer", ""))
			if selected_answer.is_empty():
				selected_answer = str(labels.get("not_answered", "Not answered"))
			var heading := "%s %s" % [
				str(labels.get("question_prefix", "Question")),
				_escape_html(str(entry.get("number", ""))),
			]
			var topic_label := str(entry.get("topic_label", ""))
			if not topic_label.is_empty():
				heading += " · " + _escape_html(topic_label)
			var gate_note := str(entry.get("gate_note", ""))
			document.append("<article class=\"entry %s\"><div class=\"entry-head\"><h2>%s</h2><span class=\"status %s\">%s</span></div><p class=\"question\">%s</p><div class=\"answers\"><div class=\"answer\"><strong>%s</strong>%s</div><div class=\"answer\"><strong>%s</strong>%s</div></div>%s</article>" % [
				status,
				heading,
				status,
				_escape_html(str(entry.get("outcome_label", ""))),
				_escape_html(str(entry.get("expression", ""))),
				_escape_html(str(labels.get("your_answer", "Your answer"))),
				_escape_html(selected_answer),
				_escape_html(str(labels.get("correct_answer", "Correct answer"))),
				_escape_html(str(entry.get("correct_answer", ""))),
				"<p class=\"gate-note\">%s</p>" % _escape_html(gate_note) if not gate_note.is_empty() else "",
			])
	document.append("<footer>%s</footer></main></body></html>" % _escape_html(str(labels.get("footer", "Paper Glide - Flight Answer Review"))))
	return "\n".join(document)


static func _escape_html(value: String) -> String:
	return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;")
