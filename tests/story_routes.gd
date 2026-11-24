extends SceneTree
## Run with godot --headless --path . --script res://tests/story_routes.gd
const Story := preload("res://scripts/story.gd")
var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("GAGAL: " + description)

func _initialize() -> void:
	for route_index in range(4):
		for skip_proof in [true, false]:
			for transmit in [true, false]:
				play_route(route_index, skip_proof, transmit)
	print("Story routes: 16; assertions: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)

func play_route(route_index: int, skip_proof: bool, transmit: bool) -> void:
	var story := Story.new()
	var reached := {}
	var extras := []
	while not story.objective().is_empty():
		if story.completed >= 54:
			check(false, "route did not terminate")
			return
		var q := story.objective()
		reached[story.chapter] = true
		for extra in story.extras():
			check(extra.id not in extras, "unique secret")
			story.interact(extra.id)
			extras.append(extra.id)
			check(extra.item in story.inventory, "secret item collected")
		var result := story.interact(q.id)
		if q.has("p"):
			var wrong: int = (int(q.p.order[0]) + 1) % q.p.cards.size()
			result = story.choose(wrong)
			check(story.objective().id == q.id, "a wrong answer stays on puzzle")
			check(bool(result.get("alarm", false)) == bool(q.p.get("alarm", false)), "panel alarm")
			for card_index in q.p.order:
				var choice: int = result.choices.find(q.p.cards[card_index])
				check(choice >= 0, "puzzle offers required card")
				result = story.choose(choice)
				if story.objective().get("id") == q.id:
					var checkpoint: Dictionary = JSON.parse_string(JSON.stringify(story.save_data()))
					story = Story.new()
					check(story.restore(checkpoint), "partial puzzle survives JSON")
					result = story.interact(q.id)
		elif q.has("decision"):
			var i := 0
			match q.id:
				"witness_B": i = int(skip_proof)
				"broadcast": i = int(not transmit)
				"plan_escape": i = route_index
			result = story.choose(i)
		check(story.objective().get("id") != q.id, "advances " + q.id)
		var saved: Dictionary = JSON.parse_string(JSON.stringify(story.save_data()))
		var restored := Story.new()
		check(restored.restore(saved), "JSON checkpoint " + q.id)
		check(restored.objective().get("id") == story.objective().get("id"), "correct objective after restore")
		story = restored
	var expected := "bad" if route_index != 0 else ("neutral" if skip_proof or not transmit else "good")
	check(story.ending == expected, "expected ending " + expected)
	check(story.completed == [53,52,52,51][route_index], "mission count")
	check(story.rescued.size() == [2,1,1,0][route_index], "evacuation party")
	check(reached.size() == 6, "all chapters")
	check(extras.size() == 15, "fifteen optional discoveries")
	var before := story.save_data()
	var broken := story.save_data()
	broken.cursor = -1
	check(not story.restore(broken), "reject bad cursor")
	check(story.save_data() == before, "invalid save does not mutate progress")
