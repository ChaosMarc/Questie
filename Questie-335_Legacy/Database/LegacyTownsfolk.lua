local Townsfolk = QuestieLoader:ImportModule("Townsfolk")
local bridge = QuestieLoader:ImportModule("LegacyTownsfolkBridge")

local classTrainers = Townsfolk.GetClassTrainers()
local mailboxes = Townsfolk.GetMailboxes()
local meetingStones = Townsfolk.GetMeetingStones()
local professionTrainers = Townsfolk.GetProfessionTrainers()

Townsfolk.GetClassTrainers = bridge.getClassTrainers
Townsfolk.GetMailboxes = bridge.getMailboxes
Townsfolk.GetMeetingStones = bridge.getMeetingStones
Townsfolk.GetProfessionTrainers = bridge.getProfessionTrainers

Townsfolk.SetClassTrainers(classTrainers)
Townsfolk.SetMailboxes(mailboxes)
Townsfolk.SetMeetingStones(meetingStones)
Townsfolk.SetProfessionTrainers(professionTrainers)
