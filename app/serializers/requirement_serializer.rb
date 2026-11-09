class RequirementSerializer
  def initialize(requirement)
    @requirement = requirement
  end

  def as_json(*)
    { id: @requirement.id, kind: @requirement.kind, text: @requirement.text, source_text: @requirement.source_text, position: @requirement.position }
  end
end
