--Update existing techs to remove redundancies.
UPDATE Technologies SET EmbarkUnitType=NULL WHERE EmbarkUnitType!=NULL;
UPDATE Technologies SET EmbarkAll='0' WHERE EmbarkAll!='0';
--Insert new tech kind.
INSERT INTO Types ( Type, Kind ) VALUES ( 'TECH_CI_EMBARKATION', 'KIND_TECH' );
--Insert new tech quote.
INSERT INTO TechnologyQuotes ( 
	TechnologyType, Quote ) VALUES ( 
	'TECH_CI_EMBARKATION',
	'LOC_CI_EMBARKATION_QUOTE' );
--Insert new tech.
INSERT INTO Technologies (
	TechnologyType, Name, Description, Cost,
	UITreeRow, AdvisorType, EmbarkAll, EraType ) VALUES (
	'TECH_CI_EMBARKATION', 'LOC_CI_EMBARKATION_NAME',
	'LOC_TECH_CI_EMBARKATION_DESCRIPTION', 0, -3,
	'ADVISOR_GENERIC', 1, 'ERA_ANCIENT' );