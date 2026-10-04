local Townsfolk = QuestieLoader:ImportModule("Townsfolk")
local bridge = QuestieLoader:ImportModule("LegacyTownsfolkBridge")

bridge.getClassTrainers = Townsfolk.GetClassTrainers
bridge.getMailboxes = Townsfolk.GetMailboxes
bridge.getMeetingStones = Townsfolk.GetMeetingStones
bridge.getProfessionTrainers = Townsfolk.GetProfessionTrainers
