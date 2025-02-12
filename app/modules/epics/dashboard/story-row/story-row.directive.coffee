###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

module = angular.module('taigaEpics')

StoryRowDirective = () ->
    return {
        templateUrl:"epics/dashboard/story-row/story-row.html",
        controller: "StoryRowCtrl",
        controllerAs: "vm",
        bindToController: true,
        scope: {
            story: '=',
            options: '='
        }
    }

module.directive("tgStoryRow", StoryRowDirective)
