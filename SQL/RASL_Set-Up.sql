-- ======================================================================================================================================
--	MAKE NO CHANGES IN THIS FILE
-- ======================================================================================================================================



CREATE TABLE IF NOT EXISTS 
    RASL_Units (
    UnitType		text,
    NumberExtraUnits	integer								default 0,
    AIMajPlayer		boolean								default 0,
    CivilizationType	text		REFERENCES Civilizations(CivilizationType)	default null,
    EraType		text		REFERENCES Eras(EraType)			default 'ERA_ANCIENT');



CREATE TABLE IF NOT EXISTS 
    RASL_Yields (
    YieldType		text,
    StartingExtraValue	integer,
    AIMajPlayer		boolean								default 0,
    CivilizationType	text		REFERENCES Civilizations(CivilizationType)	default null,
    EraType		text		REFERENCES Eras(EraType)			default 'ERA_ANCIENT');



CREATE TABLE IF NOT EXISTS 
    RASL_CivicsStatus (
    CivicType		text		REFERENCES Civics(CivicType)			default null,
    Value		integer								default 0,
    Finish		boolean								default 0,
    AIMajPlayer		boolean								default 0,
    CivilizationType	text		REFERENCES Civilizations(CivilizationType)	default null,
    EraType		text		REFERENCES Eras(EraType)			default 'ERA_ANCIENT');


CREATE TABLE IF NOT EXISTS 
    RASL_TechnologiesStatus (
    TechnologyType	text		REFERENCES Technologies(TechnologyType)		default null,
    Value		integer								default 0,
    Finish		boolean								default 0,
    AIMajPlayer		boolean								default 0,
    CivilizationType	text		REFERENCES Civilizations(CivilizationType)	default null,
    EraType		text		REFERENCES Eras(EraType)			default 'ERA_ANCIENT');

--this table defined but not implemented as yet
CREATE TABLE IF NOT EXISTS 
    RASL_ExtraStartingResources (
    ResourceType	text		REFERENCES Resources(ResourceType)		default null,
    NumberResources	integer								default 1,
    PlaceWithinX_Tiles	integer								default -1,
    AIMajPlayer		boolean								default 0,
    CivilizationType	text		REFERENCES Civilizations(CivilizationType)	default null,
    EraType		text		REFERENCES Eras(EraType)			default 'ERA_ANCIENT');


-- ======================================================================================================================================




