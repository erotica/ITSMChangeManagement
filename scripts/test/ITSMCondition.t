# --
# ITSMCondition.t - Condition tests
# Copyright (C) 2003-2010 OTRS AG, http://otrs.com/
# --
# $Id: ITSMCondition.t,v 1.58 2010-01-30 10:31:41 bes Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars qw($Self);

use Data::Dumper;

use Kernel::System::ITSMChange;
use Kernel::System::ITSMChange::ITSMWorkOrder;
use Kernel::System::ITSMChange::ITSMCondition;

# ------------------------------------------------------------ #
# make preparations
# ------------------------------------------------------------ #

my $TestCount = 1;

# create common objects
$Self->{ChangeObject}    = Kernel::System::ITSMChange->new( %{$Self} );
$Self->{WorkOrderObject} = Kernel::System::ITSMChange::ITSMWorkOrder->new( %{$Self} );
$Self->{ConditionObject} = Kernel::System::ITSMChange::ITSMCondition->new( %{$Self} );

# test if change object was created successfully
$Self->True(
    $Self->{ChangeObject},
    'Test ' . $TestCount++ . ' - construction of change object',
);

# test if workorder object was created successfully
$Self->True(
    $Self->{WorkOrderObject},
    'Test ' . $TestCount++ . ' - construction of workorder object',
);

# test if condition object was created successfully
$Self->True(
    $Self->{ConditionObject},
    'Test ' . $TestCount++ . ' - construction of condition object',
);

# turn off SendNotifications, in order to avoid a lot of useless mails
my $SendNotificationsOrg = $Self->{ConfigObject}->Get('ITSMChange::SendNotifcations');
$Self->{ConfigObject}->Set(
    Key   => 'ITSMChange::SendNotifications',
    Value => 0,
);

# ------------------------------------------------------------ #
# test Condition API
# ------------------------------------------------------------ #

# define public interface (in alphabetical order)
my @ObjectMethods = qw(
    AttributeAdd
    AttributeDelete
    AttributeGet
    AttributeList
    AttributeLookup
    AttributeUpdate
    ConditionAdd
    ConditionDelete
    ConditionDeleteAll
    ConditionGet
    ConditionList
    ConditionMatchExecute
    ConditionMatchExecuteAll
    ConditionUpdate
    ExpressionAdd
    ExpressionDelete
    ExpressionDeleteAll
    ExpressionGet
    ExpressionList
    ExpressionMatch
    ExpressionUpdate
    ObjectAdd
    ObjectDelete
    ObjectGet
    ObjectList
    ObjectLookup
    ObjectUpdate
    OperatorAdd
    OperatorDelete
    OperatorExecute
    OperatorGet
    OperatorList
    OperatorLookup
    OperatorUpdate
);

# check if subs are available
for my $ObjectMethod (@ObjectMethods) {
    $Self->True(
        $Self->{ConditionObject}->can($ObjectMethod),
        'Test ' . $TestCount++ . " - check 'can $ObjectMethod'",
    );
}

#------------------------
# make some preparations
#------------------------

# create new change
my @ChangeIDs;
my @ChangeTitles;
CREATECHANGE:
for my $CreateChange ( 0 .. 9 ) {
    my $ChangeTitle = 'UnitTestChange' . $CreateChange;
    my $ChangeID    = $Self->{ChangeObject}->ChangeAdd(
        ChangeTitle => $ChangeTitle,
        UserID      => 1,
    );

    $Self->True(
        $ChangeID,
        'Test ' . $TestCount++ . " - ChangeAdd -> $ChangeID",
    );

    # do not store change id if add failed
    next CREATECHANGE if !$ChangeID;

    # store change id for further usage and deletion
    push @ChangeIDs,    $ChangeID;
    push @ChangeTitles, $ChangeTitle;
}

# create new workorders
my @WorkOrderIDs;
my @WorkOrderTitles;
CREATEWORKORDER:
for my $CreateWorkOrder ( 0 .. ( ( 3 * ( scalar @ChangeIDs ) ) - 1 ) ) {
    my $WorkOrderTitle = 'UnitTestWO' . $CreateWorkOrder;
    my $WorkOrderID    = $Self->{WorkOrderObject}->WorkOrderAdd(
        ChangeID => $ChangeIDs[ ( $CreateWorkOrder % scalar @ChangeIDs ) ],
        WorkOrderTitle   => $WorkOrderTitle,
        PlannedStartTime => $Self->{TimeObject}->CurrentTimestamp(),
        PlannedEndTime   => $Self->{TimeObject}->SystemTime2TimeStamp(
            SystemTime => ( $Self->{TimeObject}->SystemTime() + 100 ),
        ),
        ActualStartTime => $Self->{TimeObject}->CurrentTimestamp(),
        ActualEndTime   => $Self->{TimeObject}->SystemTime2TimeStamp(
            SystemTime => ( $Self->{TimeObject}->SystemTime() + 100 ),
        ),
        UserID => 1,
    );

    $Self->True(
        $WorkOrderID,
        'Test ' . $TestCount++ . ' - WorkOrderAdd (ChangeID: '
            . $ChangeIDs[ ( $CreateWorkOrder % scalar @ChangeIDs ) ] . ") -> $WorkOrderID",
    );

    # do not store workorder id if add failed
    next CREATEWORKORDER if !$WorkOrderID;

    # store workorder id for further usage and deletion
    push @WorkOrderIDs,    $WorkOrderID;
    push @WorkOrderTitles, $WorkOrderTitle;
}

#------------------------
# condition tests
#------------------------

# create new condition
my @ConditionIDs;
my %ConditionCount;
CHANGEID:
for my $ChangeID (@ChangeIDs) {

    # add some conditions to each change
    CONDITIONCOUNTER:
    for my $ConditionCounter ( 0 .. 5 ) {

        # build condition name
        my $ConditionName = "UnitTestConditionName_${ChangeID}_" . int rand 1_000_000;

        # add a condition
        my $ConditionID = $Self->{ConditionObject}->ConditionAdd(
            ChangeID              => $ChangeID,
            Name                  => $ConditionName,
            ExpressionConjunction => 'all',
            ValidID               => 1,
            UserID                => 1,
        );

        $Self->True(
            $ConditionID,
            'Test ' . $TestCount++ . " - ConditionAdd -> ConditionID: $ConditionID",
        );

        next CONDITIONCOUNTER if !$ConditionID;

        # remember change id for later tests
        $ConditionCount{$ChangeID}++;

        # get the added condition
        my $ConditionData = $Self->{ConditionObject}->ConditionGet(
            ConditionID => $ConditionID,
            UserID      => 1,
        );

        $Self->Is(
            $ConditionData->{ConditionID},
            $ConditionID,
            'Test ' . $TestCount++ . " - ConditionGet -> ConditionID: $ConditionID",
        );

        # remember all created conditions ids
        push @ConditionIDs, $ConditionID;

        # condition update tests
        my $Success = $Self->{ConditionObject}->ConditionUpdate(
            ConditionID           => $ConditionID,
            ExpressionConjunction => 'all',
            Comment               => 'An updated comment',
            UserID                => 1,
        );

        $Self->True(
            $Success,
            'Test ' . $TestCount++ . " - ConditionUpdate -> ConditionID: $ConditionID",
        );

        # get the updated condition
        $ConditionData = $Self->{ConditionObject}->ConditionGet(
            ConditionID => $ConditionID,
            UserID      => 1,
        );

        $Self->Is(
            $ConditionData->{Comment},
            'An updated comment',
            'Test ' . $TestCount++ . " - ConditionGet -> ConditionID: $ConditionID",
        );

        # try to add the same condition again (ChangeID and Name are the same) (must fail)
        $ConditionID = $Self->{ConditionObject}->ConditionAdd(
            ChangeID              => $ChangeID,
            Name                  => $ConditionName,
            ExpressionConjunction => 'all',
            ValidID               => 1,
            UserID                => 1,
        );

        $Self->False(
            $ConditionID,
            'Test ' . $TestCount++ . " - ConditionAdd",
        );

        # just in case if the condition could be added
        if ($ConditionID) {
            push @ConditionIDs, $ConditionID;
        }
    }
}

# condition list test
CHANGEID:
for my $ChangeID ( keys %ConditionCount ) {

    # get condition list
    my $ConditionIDsRef = $Self->{ConditionObject}->ConditionList(
        ChangeID => $ChangeID,
        Valid    => 1,
        UserID   => 1,
    );

    $Self->Is(
        scalar @{$ConditionIDsRef},
        $ConditionCount{$ChangeID},
        'Test ' . $TestCount++ . " - ConditionList -> Number of conditions for ChangeID: $ChangeID",
    );

    # if no conditions exist for this change
    next CHANGEID if !@{$ConditionIDsRef};

    # set the first condition of the current change invalid
    my $Success = $Self->{ConditionObject}->ConditionUpdate(
        ConditionID => $ConditionIDsRef->[0],
        ValidID     => 2,                       # invalid
        UserID      => 1,
    );

    $Self->True(
        $Success,
        'Test ' . $TestCount++ . " - ConditionUpdate -> ConditionID: $ConditionIDsRef->[0]",
    );

    # get condition list again
    $ConditionIDsRef = $Self->{ConditionObject}->ConditionList(
        ChangeID => $ChangeID,
        Valid    => 1,
        UserID   => 1,
    );

    $Self->Is(
        scalar @{$ConditionIDsRef},
        $ConditionCount{$ChangeID} - 1,
        'Test ' . $TestCount++ . " - ConditionList -> Number of conditions for ChangeID: $ChangeID",
    );

    # get condition list again, but now with also the invalid conditions
    $ConditionIDsRef = $Self->{ConditionObject}->ConditionList(
        ChangeID => $ChangeID,
        Valid    => 0,
        UserID   => 1,
    );

    $Self->Is(
        scalar @{$ConditionIDsRef},
        $ConditionCount{$ChangeID},
        'Test ' . $TestCount++ . " - ConditionList -> Number of conditions for ChangeID: $ChangeID",
    );

}

#------------------------
# condition object tests
#------------------------

# check for default condition objects
my @ConditionObjects = qw(ITSMChange ITSMWorkOrder);

# check condition objects
for my $ConditionObject (@ConditionObjects) {

    # make lookup to get object id
    my $ObjectID = $Self->{ConditionObject}->ObjectLookup(
        Name   => $ConditionObject,
        UserID => 1,
    ) || '';

    # check on return value
    $Self->True(
        $ObjectID,
        'Test ' . $TestCount++ . " - ObjectLookup on '$ConditionObject' -> ObjectID: $ObjectID",
    );

    # get object data with object id
    my $ObjectData = $Self->{ConditionObject}->ObjectGet(
        ObjectID => $ObjectID,
        UserID   => 1,
    );

    # check return parameters
    $Self->Is(
        $ObjectData->{Name},
        $ConditionObject,
        'Test ' . $TestCount++ . ' - ObjectGet() name check',
    );
}

# check for object add
my @ConditionObjectCreated;
for my $Counter ( 1 .. 3 ) {

    # add new objects
    my $ObjectID = $Self->{ConditionObject}->ObjectAdd(
        Name   => 'ObjectName' . $Counter . int rand 1_000_000,
        UserID => 1,
    );

    # check on return value
    $Self->True(
        $ObjectID,
        'Test ' . $TestCount++ . " - ObjectAdd -> ObjectID: $ObjectID",
    );

    # save object id for delete test
    push @ConditionObjectCreated, $ObjectID;
}

# check condition object list
my $ObjectList = $Self->{ConditionObject}->ObjectList(
    UserID => 1,
);

# check for object list
$Self->True(
    $ObjectList,
    'Test ' . $TestCount++ . " - ObjectList is not empty",
);

# check for object list as hash ref
$Self->Is(
    ref $ObjectList,
    'HASH',
    'Test ' . $TestCount++ . " - ObjectList type",
);

# check update of condition object
my $ConditionObjectNewName = 'UnitTestUpdate' . int rand 1_000_000;
$Self->True(
    $Self->{ConditionObject}->ObjectUpdate(
        ObjectID => $ConditionObjectCreated[0],
        Name     => $ConditionObjectNewName,
        UserID   => 1,
    ),
    'Test ' . $TestCount++ . " - ObjectUpdate",
);
my $ConditionObjectUpdate = $Self->{ConditionObject}->ObjectGet(
    ObjectID => $ConditionObjectCreated[0],
    UserID   => 1,
);
$Self->Is(
    $ConditionObjectUpdate->{Name},
    $ConditionObjectNewName,
    'Test ' . $TestCount++ . " - ObjectUpdate verify update",
);

# check for object delete
for my $ObjectID (@ConditionObjectCreated) {
    $Self->True(
        $Self->{ConditionObject}->ObjectDelete(
            ObjectID => $ObjectID,
            UserID   => 1,
        ),
        'Test ' . $TestCount++ . " - ObjectDelete -> ObjectID: $ObjectID",
    );
}

#----------------------------
# condition attributes tests
#----------------------------

# check for default condition attributes
my @ConditionAttributes = qw(
    ChangeTitle      CategoryID      ImpactID PriorityID PlannedEffort    AccountedTime
    ChangeManagerID  ChangeBuilderID WorkOrderAgentID
    WorkOrderTitle   WorkOrderNumber WorkOrderStateID    WorkOrderTypeID
    PlannedStartTime PlannedEndTime  ActualStartTime     ActualEndTime
);

# check condition attributes
for my $ConditionAttribute (@ConditionAttributes) {

    # make lookup to get attribute id
    my $AttributeID = $Self->{ConditionObject}->AttributeLookup(
        Name => $ConditionAttribute,
    ) || '';

    # check on return value
    $Self->True(
        $AttributeID,
        'Test '
            . $TestCount++
            . " - AttributeLookup on '$ConditionAttribute' -> AttributeID: $AttributeID'",
    );

    # get attribute data with attribute id
    my $AttributeData = $Self->{ConditionObject}->AttributeGet(
        UserID      => 1,
        AttributeID => $AttributeID,
    );

    # check return parameters
    $Self->Is(
        $AttributeData->{Name},
        $ConditionAttribute,
        'Test ' . $TestCount++ . ' - AttributeGet() name check',
    );
}

# check for object add
my @ConditionAttributeCreated;
for my $Counter ( 1 .. 3 ) {

    # add new objects
    my $AttributeID = $Self->{ConditionObject}->AttributeAdd(
        UserID => 1,
        Name   => 'AttributeName' . $Counter . int rand 1_000_000,
    );

    # check on return value
    $Self->True(
        $AttributeID,
        'Test ' . $TestCount++ . " - AttributeAdd -> AttributeID: $AttributeID",
    );

    # save object it for delete test
    push @ConditionAttributeCreated, $AttributeID;
}

# check condition attribute list
my $AttributeList = $Self->{ConditionObject}->AttributeList(
    UserID => 1,
);

# check for attribute list
$Self->True(
    $AttributeList,
    'Test ' . $TestCount++ . " - AttributeList is not empty",
);

# check for attribute list as hash ref
$Self->Is(
    ref $AttributeList,
    'HASH',
    'Test ' . $TestCount++ . " - AttributeList type",
);

# check update of attribute object
my $ConditionAttributeNewName = 'UnitTestUpdate' . int rand 1_000_000;
$Self->True(
    $Self->{ConditionObject}->AttributeUpdate(
        UserID      => 1,
        AttributeID => $ConditionAttributeCreated[0],
        Name        => $ConditionAttributeNewName,
    ),
    'Test ' . $TestCount++ . " - AttributeUpdate",
);
my $ConditionAttributeUpdate = $Self->{ConditionObject}->AttributeGet(
    UserID      => 1,
    AttributeID => $ConditionAttributeCreated[0],
);
$Self->Is(
    $ConditionAttributeUpdate->{Name},
    $ConditionAttributeNewName,
    'Test ' . $TestCount++ . " - AttributeUpdate verify update",
);

# check for attribute delete
for my $AttributeID (@ConditionAttributeCreated) {
    $Self->True(
        $Self->{ConditionObject}->AttributeDelete(
            UserID      => 1,
            AttributeID => $AttributeID,
        ),
        'Test ' . $TestCount++ . " - AttributeDelete -> AttributeID: $AttributeID",
    );
}

#-------------------------
# condition operator tests
#-------------------------

# check for default condition operators
my @ConditionOperators = (

    # common matching
    'is', 'is not', 'is empty', 'is not empty',

    # digit matching
    'is greater than', 'is less than',

    # date matching
    'is before', 'is after',

    # string matching
    'contains', 'not contains', 'begins with', 'ends with',

    # action operator
    'set', 'lock',
);

# check condition operators
for my $ConditionOperator (@ConditionOperators) {

    # make lookup to get operator id
    my $OperatorID = $Self->{ConditionObject}->OperatorLookup( Name => $ConditionOperator ) || '';

    # check on return value
    $Self->True(
        $OperatorID,
        'Test '
            . $TestCount++
            . " - OperatorLookup on '$ConditionOperator' -> OperatorID: $OperatorID",
    );

    # get operator data with operator id
    my $OperatorData = $Self->{ConditionObject}->OperatorGet(
        UserID     => 1,
        OperatorID => $OperatorID,
    );

    # check return parameters
    $Self->Is(
        $OperatorData->{Name},
        $ConditionOperator,
        'Test ' . $TestCount++ . ' - OperatorGet() name check',
    );
}

# check for object add
my @ConditionOperatorCreated;
for my $Counter ( 1 .. 3 ) {

    # add new objects
    my $OperatorID = $Self->{ConditionObject}->OperatorAdd(
        UserID => 1,
        Name   => 'OperatorName' . $Counter . int rand 1_000_000,
    );

    # check on return value
    $Self->True(
        $OperatorID,
        'Test ' . $TestCount++ . " - OperatorAdd -> OperatorID: $OperatorID",
    );

    # save object it for delete test
    push @ConditionOperatorCreated, $OperatorID;
}

# check condition operator list
my $OperatorList = $Self->{ConditionObject}->OperatorList(
    UserID => 1,
);

# check for operator list
$Self->True(
    $OperatorList,
    'Test ' . $TestCount++ . " - OperatorList is not empty",
);

# check for operator list as hash ref
$Self->Is(
    ref $OperatorList,
    'HASH',
    'Test ' . $TestCount++ . " - OperatorList type",
);

# check update of operator object
my $ConditionOperatorNewName = 'UnitTestUpdate' . int rand 1_000_000;
$Self->True(
    $Self->{ConditionObject}->OperatorUpdate(
        UserID     => 1,
        OperatorID => $ConditionOperatorCreated[0],
        Name       => $ConditionOperatorNewName,
    ),
    'Test ' . $TestCount++ . " - OperatorUpdate",
);
my $ConditionOperatorUpdate = $Self->{ConditionObject}->OperatorGet(
    UserID     => 1,
    OperatorID => $ConditionOperatorCreated[0],
);
$Self->Is(
    $ConditionOperatorUpdate->{Name},
    $ConditionOperatorNewName,
    'Test ' . $TestCount++ . " - OperatorUpdate verify update",
);

# check for operator delete
for my $OperatorID (@ConditionOperatorCreated) {
    $Self->True(
        $Self->{ConditionObject}->OperatorDelete(
            UserID     => 1,
            OperatorID => $OperatorID,
        ),
        'Test ' . $TestCount++ . " - OperatorDelete -> OperatorID: $OperatorID",
    );
}

#-------------------------
# condition expression tests
#-------------------------

# check for default condition expressions
my @ExpressionTests = (
    {
        MatchSuccess => 0,
        SourceData   => {
            ExpressionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name => 'ITSMChange',
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name => 'ChangeTitle',
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name => 'is',
                    },
                },

                # static fields
                ConditionID  => $ConditionIDs[0],
                Selector     => $ChangeIDs[0],
                CompareValue => 'DummyCompareValue1',
                UserID       => 1,
            },
        },
    },
    {
        SourceData => {
            ExpressionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name => 'ITSMChange',
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name => 'ChangeManagerID',
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name => 'is',
                    },
                },

                # static fields
                ConditionID  => $ConditionIDs[0],
                Selector     => $ChangeIDs[0],
                CompareValue => 'DummyCompareValue1',
                UserID       => 1,
            },
        },
    },
    {
        SourceData => {
            ExpressionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name => 'ITSMWorkOrder',
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name => 'WorkOrderTitle',
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name => 'is not',
                    },
                },

                # static fields
                ConditionID  => $ConditionIDs[1],
                Selector     => $WorkOrderIDs[1],
                CompareValue => 'DummyCompareValue2',
                UserID       => 1,
            },
            ExpressionUpdate => {
                ObjectID => {
                    ObjectLookup => {
                        Name => 'ITSMChange',
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name => 'ChangeTitle',
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name => 'is',
                    },
                },

                # static fields
                Selector     => $ChangeIDs[0],
                CompareValue => 'NewDummyCompareValue' . int rand 1_000_000,
                UserID       => 1,
            },
        },
    },
    {
        MatchSuccess => 1,
        SourceData   => {
            ExpressionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name => 'ITSMWorkOrder',
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name => 'WorkOrderTitle',
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name => 'is not',
                    },
                },

                # static fields
                ConditionID  => $ConditionIDs[0],
                Selector     => $WorkOrderIDs[1],
                CompareValue => $WorkOrderTitles[0],
                UserID       => 1,
            },
            ExpressionUpdate => {
                UserID => 1,
            },
        },
    },
    {
        SourceData => {
            ExpressionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name => 'ITSMChange',
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name => 'PlannedStartTime',
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name => 'is greater than',
                    },
                },

                # static fields
                ConditionID  => $ConditionIDs[1],
                Selector     => $ChangeIDs[0],
                CompareValue => 'DummyCompareValue2',
                UserID       => 1,
            },
            ExpressionUpdate => {
                ObjectID => {
                    ObjectLookup => {
                        Name => 'ITSMWorkOrder',
                    },
                },

                # static fields
                Selector => $WorkOrderIDs[1],
                UserID   => 1,
            },
        },
    },
    {
        MatchSuccess => 1,
        SourceData   => {
            ExpressionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name => 'ITSMChange',
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name => 'ChangeTitle',
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name => 'is',
                    },
                },

                # static fields
                ConditionID  => $ConditionIDs[0],
                Selector     => $ChangeIDs[0],
                CompareValue => $ChangeTitles[0],
                UserID       => 1,
            },
        },
    },
    {
        MatchSuccess => 0,
        SourceData   => {
            ExpressionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name => 'ITSMChange',
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name => 'ChangeTitle',
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name => 'is not',
                    },
                },

                # static fields
                ConditionID  => $ConditionIDs[0],
                Selector     => $ChangeIDs[0],
                CompareValue => $ChangeTitles[0],
                UserID       => 1,
            },
        },
    },
    {
        MatchSuccess => 1,
        SourceData   => {
            ExpressionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name => 'ITSMChange',
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name => 'ChangeTitle',
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name => 'is not',
                    },
                },

                # static fields
                ConditionID  => $ConditionIDs[0],
                Selector     => $ChangeIDs[0],
                CompareValue => $ChangeTitles[0] . int rand 1_000_000,
                UserID       => 1,
            },
        },
    },
    {
        MatchSuccess => 1,
        SourceData   => {
            ExpressionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name => 'ITSMWorkOrder',
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name => 'WorkOrderTitle',
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name => 'is',
                    },
                },

                # static fields
                ConditionID  => $ConditionIDs[0],
                Selector     => $WorkOrderIDs[0],
                CompareValue => $WorkOrderTitles[0],
                UserID       => 1,
            },
        },
    },
    {
        MatchSuccess => 0,
        SourceData   => {
            ExpressionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name => 'ITSMWorkOrder',
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name => 'WorkOrderTitle',
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name => 'is',
                    },
                },

                # static fields
                ConditionID  => $ConditionIDs[2],
                Selector     => 'all',
                CompareValue => $WorkOrderTitles[8],
                UserID       => 1,
            },
        },
    },
    {
        MatchSuccess => 1,
        SourceData   => {
            ExpressionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name => 'ITSMWorkOrder',
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name => 'WorkOrderTitle',
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name => 'is',
                    },
                },

                # static fields
                ConditionID  => $ConditionIDs[2],
                Selector     => 'any',
                CompareValue => $WorkOrderTitles[0],
                UserID       => 1,
            },
        },
    },
    {
        MatchSuccess => 0,
        SourceData   => {
            ExpressionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name => 'ITSMWorkOrder',
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name => 'WorkOrderTitle',
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name => 'is empty',
                    },
                },

                # static fields
                ConditionID  => $ConditionIDs[2],
                Selector     => $WorkOrderIDs[0],
                CompareValue => $WorkOrderTitles[0],
                UserID       => 1,
            },
        },
    },
    {
        MatchSuccess => 1,
        SourceData   => {
            ExpressionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name => 'ITSMWorkOrder',
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name => 'WorkOrderTitle',
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name => 'is not empty',
                    },
                },

                # static fields
                ConditionID  => $ConditionIDs[2],
                Selector     => $WorkOrderIDs[0],
                CompareValue => $WorkOrderTitles[0],
                UserID       => 1,
            },
        },
    },
    {
        MatchSuccess => 1,
        SourceData   => {
            ExpressionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name => 'ITSMWorkOrder',
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name => 'WorkOrderNumber',
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name => 'is greater than',
                    },
                },

                # static fields
                ConditionID  => $ConditionIDs[2],
                Selector     => $WorkOrderIDs[0],
                CompareValue => 0,
                UserID       => 1,
            },
        },
    },
    {
        MatchSuccess => 0,
        SourceData   => {
            ExpressionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name => 'ITSMWorkOrder',
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name => 'WorkOrderNumber',
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name => 'is greater than',
                    },
                },

                # static fields
                ConditionID  => $ConditionIDs[2],
                Selector     => $WorkOrderIDs[0],
                CompareValue => 1_000_000,
                UserID       => 1,
            },
        },
    },
    {
        MatchSuccess => 1,
        SourceData   => {
            ExpressionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name => 'ITSMWorkOrder',
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name => 'WorkOrderNumber',
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name => 'is less than',
                    },
                },

                # static fields
                ConditionID  => $ConditionIDs[2],
                Selector     => $WorkOrderIDs[0],
                CompareValue => 1_000_000,
                UserID       => 1,
            },
        },
    },
    {
        MatchSuccess => 0,
        SourceData   => {
            ExpressionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name => 'ITSMWorkOrder',
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name => 'WorkOrderNumber',
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name => 'is less than',
                    },
                },

                # static fields
                ConditionID  => $ConditionIDs[2],
                Selector     => $WorkOrderIDs[0],
                CompareValue => 0,
                UserID       => 1,
            },
        },
    },
    {
        MatchSuccess => 1,
        SourceData   => {
            ExpressionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name => 'ITSMWorkOrder',
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name => 'PlannedStartTime',
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name => 'is before',
                    },
                },

                # static fields
                ConditionID  => $ConditionIDs[2],
                Selector     => $WorkOrderIDs[0],
                CompareValue => $Self->{TimeObject}->SystemTime2TimeStamp(
                    SystemTime => ( $Self->{TimeObject}->SystemTime() + 10 ),
                ),
                UserID => 1,
            },
        },
    },
    {
        MatchSuccess => 0,
        SourceData   => {
            ExpressionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name => 'ITSMWorkOrder',
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name => 'PlannedStartTime',
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name => 'is before',
                    },
                },

                # static fields
                ConditionID  => $ConditionIDs[2],
                Selector     => $WorkOrderIDs[0],
                CompareValue => $Self->{TimeObject}->SystemTime2TimeStamp(
                    SystemTime => ( $Self->{TimeObject}->SystemTime() - 10 ),
                ),
                UserID => 1,
            },
        },
    },
    {
        MatchSuccess => 1,
        SourceData   => {
            ExpressionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name => 'ITSMWorkOrder',
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name => 'PlannedStartTime',
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name => 'is after',
                    },
                },

                # static fields
                ConditionID  => $ConditionIDs[2],
                Selector     => $WorkOrderIDs[0],
                CompareValue => $Self->{TimeObject}->SystemTime2TimeStamp(
                    SystemTime => ( $Self->{TimeObject}->SystemTime() - 10 ),
                ),
                UserID => 1,
            },
        },
    },
    {
        MatchSuccess => 0,
        SourceData   => {
            ExpressionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name => 'ITSMWorkOrder',
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name => 'PlannedStartTime',
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name => 'is after',
                    },
                },

                # static fields
                ConditionID  => $ConditionIDs[2],
                Selector     => $WorkOrderIDs[0],
                CompareValue => $Self->{TimeObject}->SystemTime2TimeStamp(
                    SystemTime => ( $Self->{TimeObject}->SystemTime() + 10 ),
                ),
                UserID => 1,
            },
        },
    },
    {
        MatchSuccess => 1,
        SourceData   => {
            ExpressionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name => 'ITSMWorkOrder',
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name => 'WorkOrderTitle',
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name => 'is',
                    },
                },

                # static fields
                ConditionID  => $ConditionIDs[2],
                Selector     => $WorkOrderIDs[0],
                CompareValue => $WorkOrderTitles[0],
                UserID       => 1,
            },
        },
    },
    {
        MatchSuccess => 1,
        SourceData   => {
            ExpressionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name => 'ITSMWorkOrder',
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name => 'WorkOrderTitle',
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name => 'contains',
                    },
                },

                # static fields
                ConditionID  => $ConditionIDs[2],
                Selector     => $WorkOrderIDs[0],
                CompareValue => substr( $WorkOrderTitles[0], -4 ),
                UserID       => 1,
            },
        },
    },
    {
        MatchSuccess => 1,
        SourceData   => {
            ExpressionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name => 'ITSMWorkOrder',
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name => 'WorkOrderTitle',
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name => 'contains',
                    },
                },

                # static fields
                ConditionID  => $ConditionIDs[2],
                Selector     => $WorkOrderIDs[0],
                CompareValue => $WorkOrderTitles[0],
                UserID       => 1,
            },
        },
    },
    {
        MatchSuccess => 0,
        SourceData   => {
            ExpressionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name => 'ITSMWorkOrder',
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name => 'WorkOrderTitle',
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name => 'contains',
                    },
                },

                # static fields
                ConditionID  => $ConditionIDs[2],
                Selector     => $WorkOrderIDs[0],
                CompareValue => 'Not A Valid Value ' . int rand 1_000_000,
                UserID       => 1,
            },
        },
    },
    {
        MatchSuccess => 1,
        SourceData   => {
            ExpressionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name => 'ITSMWorkOrder',
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name => 'WorkOrderTitle',
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name => 'not contains',
                    },
                },

                # static fields
                ConditionID  => $ConditionIDs[2],
                Selector     => $WorkOrderIDs[0],
                CompareValue => 'Not A Valid Value ' . int rand 1_000_000,
                UserID       => 1,
            },
        },
    },
    {
        MatchSuccess => 0,
        SourceData   => {
            ExpressionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name => 'ITSMWorkOrder',
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name => 'WorkOrderTitle',
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name => 'not contains',
                    },
                },

                # static fields
                ConditionID  => $ConditionIDs[2],
                Selector     => $WorkOrderIDs[0],
                CompareValue => $WorkOrderTitles[0],
                UserID       => 1,
            },
        },
    },
    {
        MatchSuccess => 1,
        SourceData   => {
            ExpressionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name => 'ITSMWorkOrder',
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name => 'WorkOrderTitle',
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name => 'begins with',
                    },
                },

                # static fields
                ConditionID  => $ConditionIDs[2],
                Selector     => $WorkOrderIDs[0],
                CompareValue => substr( $WorkOrderTitles[0], 0, 4 ),
                UserID       => 1,
            },
        },
    },
    {
        MatchSuccess => 0,
        SourceData   => {
            ExpressionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name => 'ITSMWorkOrder',
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name => 'WorkOrderTitle',
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name => 'begins with',
                    },
                },

                # static fields
                ConditionID  => $ConditionIDs[2],
                Selector     => $WorkOrderIDs[0],
                CompareValue => substr( $WorkOrderTitles[0], 1 ),
                UserID       => 1,
            },
        },
    },
    {
        MatchSuccess => 1,
        SourceData   => {
            ExpressionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name => 'ITSMWorkOrder',
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name => 'WorkOrderTitle',
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name => 'ends with',
                    },
                },

                # static fields
                ConditionID  => $ConditionIDs[2],
                Selector     => $WorkOrderIDs[0],
                CompareValue => substr( $WorkOrderTitles[0], -4 ),
                UserID       => 1,
            },
        },
    },
    {
        MatchSuccess => 0,
        SourceData   => {
            ExpressionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name => 'ITSMWorkOrder',
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name => 'WorkOrderTitle',
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name => 'ends with',
                    },
                },

                # static fields
                ConditionID  => $ConditionIDs[2],
                Selector     => $WorkOrderIDs[0],
                CompareValue => substr( $WorkOrderTitles[0], 1, 3 ),
                UserID       => 1,
            },
        },
    },
);

# check condition expressions
my @ExpressionIDs;
EXPRESSIONTEST:
for my $ExpressionTest (@ExpressionTests) {

    # store data of test cases locally
    my %SourceData;
    my $ExpressionID;
    my %ExpressionAddSourceData;
    my %ExpressionAddData;

    # extract source data
    if ( $ExpressionTest->{SourceData} ) {
        %SourceData = %{ $ExpressionTest->{SourceData} };
    }

    next EXPRESSIONTEST if !%SourceData;

    CREATEDATA:
    for my $CreateData ( keys %SourceData ) {

        # add expression
        if ( $CreateData eq 'ExpressionAdd' ) {

            # extract ExpressionAdd data
            %ExpressionAddSourceData = %{ $SourceData{$CreateData} };

            # set static fields
            my @StaticFields = qw( Selector CompareValue UserID ConditionID );

            STATICFIELD:
            for my $StaticField (@StaticFields) {

                # ommit static field if it is not set
                next STATICFIELD if !exists $ExpressionAddSourceData{$StaticField}
                        || !defined $ExpressionAddSourceData{$StaticField};

                # safe data
                $ExpressionAddData{$StaticField} = $ExpressionAddSourceData{$StaticField};
            }

            # get all fields for ExpressionAdd
            for my $ExpressionAddValue ( keys %ExpressionAddSourceData ) {

                # ommit static fields
                next if grep { $_ eq $ExpressionAddValue } @StaticFields;

                # get values for fields
                for my $FieldValue ( keys %{ $ExpressionAddSourceData{$ExpressionAddValue} } ) {

                    # store gathered information in hash for adding
                    $ExpressionAddData{$ExpressionAddValue} =
                        $Self->{ConditionObject}->$FieldValue(
                        %{ $ExpressionAddSourceData{$ExpressionAddValue}->{$FieldValue} },
                        );
                }
            }

            # add expression
            $ExpressionID = $Self->{ConditionObject}->ExpressionAdd(
                %ExpressionAddData,
            ) || 0;

            $Self->True(
                $ExpressionID,
                'Test ' . $TestCount++ . " - $CreateData -> $ExpressionID",
            );

            next CREATEDATA if !$ExpressionID;

            # save created ID for deleting expressions
            push @ExpressionIDs, $ExpressionID;

            # check the added expression
            my $ExpressionGetData = $Self->{ConditionObject}->ExpressionGet(
                ExpressionID => $ExpressionID,
                UserID       => $ExpressionAddData{UserID},
            );
            $Self->True(
                $ExpressionGetData,
                'Test ' . $TestCount++ . ' - ExpressionAdd(): ExpressionGet',
            );

            # test values
            delete $ExpressionAddData{UserID};
            for my $TestValue ( keys %ExpressionAddData ) {
                $Self->Is(
                    $ExpressionGetData->{$TestValue},
                    $ExpressionAddData{$TestValue},
                    'Test ' . $TestCount++ . " - ExpressionAdd(): ExpressionGet -> $TestValue",
                );
            }
        }    # end if ( $CreateData eq 'ExpressionAdd' )

        # update expression
        if ( $CreateData eq 'ExpressionUpdate' ) {

            # extract ExpressionUpdate data
            my %ExpressionUpdateSourceData = %{ $SourceData{$CreateData} };
            my %ExpressionUpdateData;

            # set static fields
            my @StaticFields = qw( Selector CompareValue UserID ConditionID );

            STATICFIELD:
            for my $StaticField (@StaticFields) {

                # ommit static field if it is not set
                next STATICFIELD if !$ExpressionUpdateSourceData{$StaticField};

                # safe data
                $ExpressionUpdateData{$StaticField} = $ExpressionUpdateSourceData{$StaticField};
            }

            # get all fields for ExpressionUpdate
            for my $ExpressionUpdateValue ( keys %ExpressionUpdateSourceData ) {

                # ommit static fields
                next if grep { $_ eq $ExpressionUpdateValue } @StaticFields;

                # get values for fields
                for my $FieldValue ( keys %{ $ExpressionUpdateSourceData{$ExpressionUpdateValue} } )
                {

                    # store gathered information in hash for updating
                    $ExpressionUpdateData{$ExpressionUpdateValue} =
                        $Self->{ConditionObject}->$FieldValue(
                        %{ $ExpressionUpdateSourceData{$ExpressionUpdateValue}->{$FieldValue} },
                        );
                }
            }

            # update expression
            my $UpdateSuccess = $Self->{ConditionObject}->ExpressionUpdate(
                ExpressionID => $ExpressionID,
                %ExpressionUpdateData,
            );

            $Self->True(
                $UpdateSuccess,
                'Test ' . $TestCount++ . " - $CreateData",
            );

            next CREATEDATA if !$UpdateSuccess;

            # check the added expression
            my $ExpressionGetData = $Self->{ConditionObject}->ExpressionGet(
                ExpressionID => $ExpressionID,
                UserID       => $ExpressionUpdateData{UserID},
            );
            $Self->True(
                $ExpressionGetData,
                'Test ' . $TestCount++ . ' - ExpressionUpdate(): ExpressionGet',
            );

            # merge add and update data
            %ExpressionUpdateData = ( %ExpressionAddData, %ExpressionUpdateData );

            # test values
            delete $ExpressionUpdateData{UserID};
            for my $TestValue ( keys %ExpressionUpdateData ) {
                $Self->Is(
                    $ExpressionGetData->{$TestValue},
                    $ExpressionUpdateData{$TestValue},
                    'Test ' . $TestCount++ . " - ExpressionUpdate(): ExpressionGet -> $TestValue",
                );
            }
        }    # end if ( $CreateData eq 'ExpressionUpdate' )
    }
}

# check for expression list
CONDITIONID:
for my $ConditionID (@ConditionIDs) {

    # check for expressions of this condition id
    my $ExpressionTestCount = 0;
    EXPRESSIONTEST:
    for my $ExpressionTest (@ExpressionTests) {

        # ommit test case if no source data is available
        next EXPRESSIONTEST if !$ExpressionTest->{SourceData};

        # ommit test case if no expression shoul be added
        next EXPRESSIONTEST if !$ExpressionTest->{SourceData}->{ExpressionAdd};

        $ExpressionTestCount++
            if $ExpressionTest->{SourceData}->{ExpressionAdd}->{ConditionID} == $ConditionID;
    }

    my $ExpressionList = $Self->{ConditionObject}->ExpressionList(
        ConditionID => $ConditionID,
        UserID      => 1,
    );

    $Self->Is(
        ref $ExpressionList,
        'ARRAY',
        'Test ' . $TestCount++ . ' - ExpressionList return value',
    );

    # check for list type
    next CONDITIONID if ref $ExpressionList ne 'ARRAY';

    $Self->Is(
        scalar @{$ExpressionList},
        $ExpressionTestCount,
        'Test ' . $TestCount++ . " - ExpressionList -> $ConditionID",
    );
}

# test for matching
for my $ExpressionCounter ( 0 .. ( scalar @ExpressionIDs - 1 ) ) {

    my $ExpressionID = $ExpressionIDs[$ExpressionCounter];

    # group related tests
    $TestCount++;

    # print info about the match test:
    $Self->True(
        1,
        "Match test $TestCount: "
            . "ExpressionCounter => $ExpressionCounter, ExpressionID => $ExpressionID",
    );

    # get object value for attributes
    my $ObjectName
        = $ExpressionTests[$ExpressionCounter]->{SourceData}->{ExpressionAdd}->{ObjectID}
        ->{ObjectLookup}->{Name};

    # check for updated object
    if (
        $ExpressionTests[$ExpressionCounter]->{SourceData}->{ExpressionUpdate}
        && $ExpressionTests[$ExpressionCounter]->{SourceData}->{ExpressionUpdate}->{ObjectID}
        ->{ObjectLookup}->{Name}
        )
    {
        $ObjectName
            = $ExpressionTests[$ExpressionCounter]->{SourceData}->{ExpressionUpdate}->{ObjectID}
            ->{ObjectLookup}->{Name};
    }

    # get attribute values for attributes
    my $AttributeName
        = $ExpressionTests[$ExpressionCounter]->{SourceData}->{ExpressionAdd}->{AttributeID}
        ->{AttributeLookup}->{Name};

    # check for updated attribute
    if (
        $ExpressionTests[$ExpressionCounter]->{SourceData}->{ExpressionUpdate}
        && $ExpressionTests[$ExpressionCounter]->{SourceData}->{ExpressionUpdate}->{AttributeID}
        ->{AttributeLookup}->{Name}
        )
    {
        $AttributeName
            = $ExpressionTests[$ExpressionCounter]->{SourceData}->{ExpressionUpdate}->{AttributeID}
            ->{AttributeLookup}->{Name};
    }

    # test on successfull result
    if ( $ExpressionTests[$ExpressionCounter]->{MatchSuccess} ) {

        # test without given changed attributes
        $Self->True(
            $Self->{ConditionObject}->ExpressionMatch(
                ExpressionID => $ExpressionID,
                UserID       => 1,
                )
                || 0,
            "Test $TestCount - ExpressionMatch return true, without changed attributes",
        );

        # test with given changed attributes
        $Self->True(
            $Self->{ConditionObject}->ExpressionMatch(
                ExpressionID      => $ExpressionID,
                AttributesChanged => { $ObjectName => [$AttributeName] },
                UserID            => 1,
                )
                || 0,
            "Test $TestCount - ExpressionMatch return true, with changed attributes",
        );

        # test with wrong given object type of changed attributes
        $Self->False(
            $Self->{ConditionObject}->ExpressionMatch(
                ExpressionID      => $ExpressionID,
                AttributesChanged => { $ObjectName . 'UT' . int rand 1_000 => [$AttributeName] },
                UserID            => 1,
                )
                || 0,
            "Test $TestCount - ExpressionMatch return false, wrong object type",
        );

        # test with wrong given attribute type of changed attributes
        $Self->False(
            $Self->{ConditionObject}->ExpressionMatch(
                ExpressionID      => $ExpressionID,
                AttributesChanged => { $ObjectName => [ $AttributeName . 'UT' . int rand 1_000 ] },
                UserID            => 1,
                )
                || 0,
            "Test $TestCount - ExpressionMatch return false, wrong attribute type",
        );
    }
    else {

        # test without given changed attributes
        $Self->False(
            $Self->{ConditionObject}->ExpressionMatch(
                ExpressionID => $ExpressionID,
                UserID       => 1,
                )
                || 0,
            "Test $TestCount - ExpressionMatch return false, without changed attributes",
        );

        # test with given changed attributes
        $Self->False(
            $Self->{ConditionObject}->ExpressionMatch(
                ExpressionID      => $ExpressionID,
                AttributesChanged => { $ObjectName => [$AttributeName] },
                UserID            => 1,
                )
                || 0,
            "Test $TestCount - ExpressionMatch return false, with changed attributes",
        );
    }
}

#-------------------------
# condition expression tests
#-------------------------

# check for default condition expressions
my @ActionTests = (
    {
        ActionSuccess => 1,
        SourceData    => {
            ActionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name   => 'ITSMChange',
                        UserID => 1,
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name   => 'ChangeTitle',
                        UserID => 1,
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name   => 'set',
                        UserID => 1,
                    },
                },

                # static fields
                ConditionID => $ConditionIDs[1],
                Selector    => $ChangeIDs[0],
                ActionValue => 'New Change Title' . int rand 1_000,
                UserID      => 1,
            },
        },
    },
    {
        ActionSuccess => 0,
        SourceData    => {
            ActionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name   => 'ITSMChange',
                        UserID => 1,
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name   => 'ChangeStateID',
                        UserID => 1,
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name   => 'lock',
                        UserID => 1,
                    },
                },

                # static fields
                ConditionID => $ConditionIDs[1],
                Selector    => $ChangeIDs[0],
                ActionValue => 1,
                UserID      => 1,
            },
        },
    },
    {
        ActionSuccess => 1,
        SourceData    => {
            ActionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name   => 'ITSMChange',
                        UserID => 1,
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name   => 'ChangeManagerID',
                        UserID => 1,
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name   => 'set',
                        UserID => 1,
                    },
                },

                # static fields
                ConditionID => $ConditionIDs[6],
                Selector    => $ChangeIDs[1],
                ActionValue => 1,
                UserID      => 1,
            },
        },
    },
    {
        ActionSuccess => 1,
        SourceData    => {
            ActionAdd => {
                ObjectID => {
                    ObjectLookup => {
                        Name   => 'ITSMWorkOrder',
                        UserID => 1,
                    },
                },
                AttributeID => {
                    AttributeLookup => {
                        Name   => 'WorkOrderTitle',
                        UserID => 1,
                    },
                },
                OperatorID => {
                    OperatorLookup => {
                        Name   => 'set',
                        UserID => 1,
                    },
                },

                # static fields
                ConditionID => $ConditionIDs[0],
                Selector    => $WorkOrderIDs[0],
                ActionValue => 'New WorkOrderTitle Title' . int rand 1_000,
                UserID      => 1,
            },
        },
    },
);

# check condition actions
my @ActionIDs;
ACTIONTEST:
for my $ActionTest (@ActionTests) {

    # store data of test cases locally
    my %SourceData;
    my $ActionID;

    # extract source data
    if ( $ActionTest->{SourceData} ) {
        %SourceData = %{ $ActionTest->{SourceData} };
    }

    # check for sour data
    next ACTIONTEST if !%SourceData;

    CREATEDATA:
    for my $CreateData ( keys %SourceData ) {

        # add action
        if ( $CreateData eq 'ActionAdd' ) {

            # add action
            $ActionID = _ActionAdd( $SourceData{$CreateData} );

            # check for action id
            next CREATEDATA if !$ActionID;

            # save created ID for deleting actions
            push @ActionIDs, $ActionID;
        }
    }
}

# check execution of actions
ACTIONCOUNTER:
for my $ActionCounter ( 0 .. ( ( scalar @ActionTests ) - 1 ) ) {

    my $ActionID = $ActionIDs[$ActionCounter] || 0;

    $Self->True(
        $ActionID,
        'Test ' . $TestCount++ . " - ActionExecute -> ActionID: $ActionID",
    );

    next ACTIONCOUNTER if !$ActionID;

    # select assert function
    my $TestSub = 'False';
    if ( $ActionTests[$ActionCounter]->{ActionSuccess} ) {
        $TestSub = 'True';
    }

    # test for result
    $Self->$TestSub(
        $Self->{ConditionObject}->ActionExecute(
            ActionID => $ActionID,
            UserID   => 1,
            )
            || 0,
        'Test ' . $TestCount++ . " - ActionExecute -> ActionID: $ActionID",
    );

    # do not execute further checks if action
    # is not supposed to be successfully
    next ACTIONCOUNTER if !$ActionTests[$ActionCounter]->{ActionSuccess};

    # check for updated action
    my $Action = $Self->{ConditionObject}->ActionGet(
        ActionID => $ActionID,
        UserID   => 1,
    );
    $Self->True(
        $Action,
        'Test ' . $TestCount++ . " - ActionExecute -> ActionGet: $ActionID",
    );
    next ACTIONCOUNTER if !$Action;

    # get object name
    my $ObjectName = $Self->{ConditionObject}->ObjectLookup(
        ObjectID => $Action->{ObjectID},
        UserID   => 1,
    );
    $Self->True(
        $ObjectName,
        'Test ' . $TestCount++ . " - ActionExecute -> ObjectLookup: $ObjectName",
    );
    next ACTIONCOUNTER if !$ObjectName;

    # get attribute name
    my $AttributeName = $Self->{ConditionObject}->AttributeLookup(
        AttributeID => $Action->{AttributeID},
        UserID      => 1,
    );
    $Self->True(
        $AttributeName,
        'Test ' . $TestCount++ . " - ActionExecute -> AttributeLookup: $AttributeName",
    );
    next ACTIONCOUNTER if !$ObjectName;

    # get object data
    my $ObjectData;
    if ( $ObjectName eq 'ITSMChange' ) {
        $ObjectData = $Self->{ChangeObject}->ChangeGet(
            ChangeID => $Action->{Selector},
            UserID   => 1,
        );
    }
    elsif ( $ObjectName eq 'ITSMWorkOrder' ) {
        $ObjectData = $Self->{WorkOrderObject}->WorkOrderGet(
            WorkOrderID => $Action->{Selector},
            UserID      => 1,
        );
    }
    $Self->True(
        $AttributeName,
        'Test ' . $TestCount++ . " - ActionExecute -> get ObjectData: $ObjectName",
    );
    next ACTIONCOUNTER if !$ObjectData;

    # check for updated value
    $Self->Is(
        $ObjectData->{$AttributeName},
        $Action->{ActionValue},
        'Test ' . $TestCount++ . " - ActionExecute -> get changed data: $ObjectName",
    );
}

# test for match state lock
$Self->False(
    $Self->{ConditionObject}->ConditionMatchStateLock(
        ObjectName => 'ITSMChange',
        Selector   => $ChangeIDs[0],
        StateID    => 1,
        UserID     => 1,
        )
        || 0,
    'Test ' . $TestCount++ . " - ConditionMatchStateLock",
);

# check for expression delete
for my $ExpressionID (@ExpressionIDs) {
    $Self->True(
        $Self->{ConditionObject}->ExpressionDelete(
            UserID       => 1,
            ExpressionID => $ExpressionID,
        ),
        'Test ' . $TestCount++ . " - ExpressionDelete -> ExpressionID: $ExpressionID",
    );

    # double check if expression is really deleted
    my $ExpressionData = $Self->{ConditionObject}->ExpressionGet(
        ExpressionID => $ExpressionID,
        UserID       => 1,
    );

    $Self->Is(
        undef,
        $ExpressionData->{ExpressionID},
        'Test' . $TestCount++ . ': ExpressionDelete() - double check',
    );
}

# check for action delete
for my $ActionID (@ActionIDs) {
    $Self->True(
        $Self->{ConditionObject}->ActionDelete(
            UserID   => 1,
            ActionID => $ActionID,
        ),
        'Test ' . $TestCount++ . " - ActionDelete -> ActionID: $ActionID",
    );

    # double check if action is really deleted
    my $ActionData = $Self->{ConditionObject}->ActionGet(
        ActionID => $ActionID,
        UserID   => 1,
    );

    $Self->Is(
        undef,
        $ActionData->{ActionID},
        'Test' . $TestCount++ . ': ActionDelete() - double check',
    );
}

# delete created conditions
for my $ConditionID (@ConditionIDs) {

    my $DeleteSuccess = $Self->{ConditionObject}->ConditionDelete(
        ConditionID => $ConditionID,
        UserID      => 1,
    );

    $Self->True(
        $DeleteSuccess,
        'Test ' . $TestCount++ . " - ConditionDelete -> ConditionID: $ConditionID",
    );

    # double check if condition is really deleted
    my $ConditionData = $Self->{ConditionObject}->ConditionGet(
        ConditionID => $ConditionID,
        UserID      => 1,
    );

    $Self->Is(
        undef,
        $ConditionData->{ConditionID},
        'Test' . $TestCount++ . ': ConditionDelete() - double check',
    );
}

# delete created changes
for my $ChangeID (@ChangeIDs) {
    $Self->True(
        $Self->{ChangeObject}->ChangeDelete(
            ChangeID => $ChangeID,
            UserID   => 1,
        ),
        'Test ' . $TestCount++ . " - ChangeDelete -> ChangeID: $ChangeID",
    );

    # double check if change is really deleted
    my $ChangeData = $Self->{ChangeObject}->ChangeGet(
        ChangeID => $ChangeID,
        UserID   => 1,
    );

    $Self->Is(
        undef,
        $ChangeData->{ChangeID},
        'Test' . $TestCount++ . ': ChangeDelete() - double check',
    );
}

# set SendNotifications to it's original value
$Self->{ConfigObject}->Set(
    Key   => 'ITSMChange::SendNotifications',
    Value => $SendNotificationsOrg,
);

sub _ActionAdd {
    my $ActionData = shift;

    return if !$ActionData;
    return if ref $ActionData ne 'HASH';

    # hash for adding
    my %ActionAdd;

    # set static fields
    my @StaticFields = qw( Selector ActionValue UserID ConditionID );

    STATICFIELD:
    for my $StaticField (@StaticFields) {

        # ommit static field if it is not set
        next STATICFIELD if !exists $ActionData->{$StaticField};
        next STATICFIELD if !defined $ActionData->{$StaticField};

        # safe data
        $ActionAdd{$StaticField} = $ActionData->{$StaticField};
    }

    # get all fields for ActionAdd
    for my $ActionAddValue ( keys %{$ActionData} ) {

        # ommit static fields
        next if grep { $_ eq $ActionAddValue } @StaticFields;

        # get values for fields
        for my $FieldValue ( keys %{ $ActionData->{$ActionAddValue} } ) {

            # store gathered information in hash for adding
            $ActionAdd{$ActionAddValue}
                = $Self->{ConditionObject}->$FieldValue(
                %{ $ActionData->{$ActionAddValue}->{$FieldValue} },
                );
        }
    }

    # add action
    my $ActionID = $Self->{ConditionObject}->ActionAdd(
        %ActionAdd,
    ) || 0;

    $Self->True(
        $ActionID,
        'Test ' . $TestCount++ . " - ActionAdd -> $ActionID",
    );

    # check for ActionID
    return if !$ActionID;

    # check the added action
    my $ActionGet = $Self->{ConditionObject}->ActionGet(
        ActionID => $ActionID,
        UserID   => $ActionAdd{UserID},
    );
    $Self->True(
        $ActionGet,
        'Test ' . $TestCount++ . ' - ActionAdd(): ActionGet',
    );

    # delete UserID, it is not returned
    delete $ActionAdd{UserID};

    # test values
    for my $TestValue ( keys %ActionAdd ) {
        $Self->Is(
            $ActionGet->{$TestValue},
            $ActionAdd{$TestValue},
            'Test ' . $TestCount++ . " - ActionAdd(): ActionGet -> $TestValue",
        );
    }

    return $ActionID;
}

1;
