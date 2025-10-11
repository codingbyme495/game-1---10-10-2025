extends Control

# Variables
@onready var document_label = $DocumentLabel
@onready var accept_button = $AcceptButton
@onready var reject_button = $RejectButton
@onready var score_label = $ScoreLabel

var documents = ["Permis A", "Permis B", "Permis Suspect"]
var current_doc = ""
var score = 0
var quota = 10

func _ready():
	randomize()
	next_document()
	accept_button.connect("pressed", Callable(self, "_on_accept"))
	reject_button.connect("pressed", Callable(self, "_on_reject"))

func next_document():
	current_doc = documents[randi() % documents.size()]
	document_label.text = "Document : " + current_doc
	score_label.text = "Score : " + str(score) + " | Quota : " + str(quota)

func _on_accept():
	if current_doc == "Permis Suspect":
		score -= 1
	else:
		score += 1
	quota -= 1
	if quota > 0:
		next_document()
	else:
		end_day()

func _on_reject():
	if current_doc == "Permis Suspect":
		score += 1
	else:
		score -= 1
	quota -= 1
	if quota > 0:
		next_document()
	else:
		end_day()

func end_day():
	document_label.text = "Journée terminée !"
	accept_button.disabled = true
	reject_button.disabled = true
	score_label.text = "Score final : " + str(score)
	# Ici, on peut ajouter une logique pour passer au jour suivant
