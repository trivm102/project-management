###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "tgCurrentUserService", ->
    currentUserService = provide = $q = $rootScope = null
    mocks = {}

    _mockTgStorage = () ->
        mocks.storageService = {
            get: sinon.stub()
        }

        provide.value "$tgStorage", mocks.storageService

    _mockProjectsService = () ->
        mocks.projectsService = {
            getProjectsByUserId: sinon.stub()
            getListProjectsByUserId: sinon.stub()
            bulkUpdateProjectsOrder: sinon.stub()
        }

        provide.value "tgProjectsService", mocks.projectsService

    _mockResources = () ->
        mocks.resources = {
            user: {
                setUserStorage: sinon.stub(),
                getUserStorage: sinon.stub(),
                createUserStorage: sinon.stub()
            }
        }

        provide.value "tgResources", mocks.resources

    _inject = (callback) ->
        inject (_tgCurrentUserService_, _$rootScope_, _$q_) ->
            currentUserService = _tgCurrentUserService_
            $rootScope = _$rootScope_
            $q = _$q_
            callback() if callback

    _mocks = () ->
        module ($provide) ->
            provide = $provide
            _mockTgStorage()
            _mockProjectsService()
            _mockResources()

            return null

    _setup = ->
        _mocks()

    beforeEach ->
        module "taigaCommon"
        _setup()
        _inject()

    describe "get user", () ->
        it "return the user if it is defined", () ->
            currentUserService._user = 123

            expect(currentUserService.getUser()).to.be.equal(123)

        it "get user form storage if it is not defined", () ->
            user = {id: 1, name: "fake1"}

            currentUserService.setUser = sinon.spy()
            mocks.storageService.get.withArgs("userInfo").returns(user)

            _user = currentUserService.getUser()

            expect(currentUserService.setUser).to.be.calledOnce

    it "set user and load user info", (done) ->
        user = Immutable.fromJS({id: 1, name: "fake1"})

        projects = Immutable.fromJS([
            {id: 1, name: "fake1"},
            {id: 2, name: "fake2"},
            {id: 3, name: "fake3"},
            {id: 4, name: "fake4"}
        ])

        mocks.projectsService.getListProjectsByUserId = sinon.stub()
        getListProjectsByUserIdDeferred = $q.defer()

        mocks.projectsService.getListProjectsByUserId.withArgs(user.get("id")).returns(getListProjectsByUserIdDeferred.promise)

        getListProjectsByUserIdDeferred.resolve(projects)

        currentUserService.setUser(user).then () ->
            expect(currentUserService._user).to.be.equal(user)
            expect(currentUserService.projects.get("all").size).to.be.equal(4)
            expect(currentUserService.projects.get("recents").size).to.be.equal(4)
            expect(currentUserService.projectsById.size).to.be.equal(4)
            expect(currentUserService.projectsById.get("3").get("name")).to.be.equal("fake3")

            done()

        $rootScope.$apply()

    it "bulkUpdateProjectsOrder and reload projects", (done) ->
        fakeData = [{id: 1, id: 2}]

        currentUserService.loadProjects = sinon.stub()

        mocks.projectsService.bulkUpdateProjectsOrder.withArgs(fakeData).promise().resolve()

        currentUserService.bulkUpdateProjectsOrder(fakeData).then () ->
            expect(currentUserService.loadProjects).to.be.callOnce

            done()

    it "loadProject and set it", (done) ->
        user = Immutable.fromJS({id: 1, name: "fake1"})
        project = Immutable.fromJS({id: 2, name: "fake2"})

        currentUserService._user = user
        currentUserService.setProjects = sinon.stub()

        mocks.projectsService.getListProjectsByUserId.withArgs(1).promise().resolve(project)

        currentUserService.loadProjectsList().then () ->
            expect(currentUserService.setProjects).to.have.been.calledWith(project)

            done()

    it "setProject", () ->
        projectsRaw = [
            {id: 1, name: "fake1"},
            {id: 2, name: "fake2"},
            {id: 3, name: "fake3"},
            {id: 4, name: "fake4"}
        ]
        projectsRawById = {
            1: {id: 1, name: "fake1"},
            2: {id: 2, name: "fake2"},
            3: {id: 3, name: "fake3"},
            4: {id: 4, name: "fake4"}
        }
        projects = Immutable.fromJS(projectsRaw)

        currentUserService.setProjects(projects)

        expect(currentUserService.projects.get('all').toJS()).to.be.eql(projectsRaw)
        expect(currentUserService.projects.get('recents').toJS()).to.be.eql(projectsRaw)
        expect(currentUserService.projectsById.toJS()).to.be.eql(projectsRawById)

    it "is authenticated", () ->
        currentUserService.getUser = sinon.stub()
        currentUserService.getUser.returns({})

        expect(currentUserService.isAuthenticated()).to.be.true

        currentUserService.getUser.returns(null)

        expect(currentUserService.isAuthenticated()).to.be.false

    it "remove user", () ->
        currentUserService._user = true

        currentUserService.removeUser()

        expect(currentUserService._user).to.be.null

    it "disable joyride for anon user", () ->
        currentUserService.isAuthenticated = sinon.stub()
        currentUserService.isAuthenticated.returns(false)
        currentUserService.disableJoyRide()

        expect(mocks.resources.user.setUserStorage).to.have.not.been.called

    it "disable joyride for logged user", () ->
        currentUserService.isAuthenticated = sinon.stub()
        currentUserService.isAuthenticated.returns(true)
        currentUserService.disableJoyRide()

        expect(mocks.resources.user.setUserStorage).to.have.been.calledWith('joyride', {
            backlog: false,
            kanban: false,
            dashboard: false
        })

    it "load joyride config", (done) ->
        getUserStorageDeferred = $q.defer()

        mocks.resources.user.getUserStorage.withArgs('joyride').returns(getUserStorageDeferred.promise)

        getUserStorageDeferred.resolve(true)

        currentUserService.loadJoyRideConfig().then (config) ->
            expect(config).to.be.true

            done()

        $rootScope.$apply()

    it "create default joyride config", (done) ->
        getUserStorageDeferred = $q.defer()

        mocks.resources.user.getUserStorage.withArgs('joyride').returns(getUserStorageDeferred.promise)

        getUserStorageDeferred.reject(new Error('error'))

        currentUserService.loadJoyRideConfig().then (config) ->
            joyride = {
                backlog: true,
                kanban: true,
                dashboard: true
            }

            expect(mocks.resources.user.createUserStorage).to.have.been.calledWith('joyride', joyride)
            expect(config).to.be.eql(joyride)

            done()

        $rootScope.$apply()

    it "the user can't create private projects if they reach the maximum number of private projects", () ->
        user = Immutable.fromJS({
            id: 1,
            name: "fake1",
            max_private_projects: 1,
            total_private_projects: 1
        })

        currentUserService._user = user

        result = currentUserService.canCreatePrivateProjects()

        expect(result).to.be.eql({
            valid: false,
            reason: 'max_private_projects',
            type: 'private_project',
            current: 1,
            max: 1
        })

    it "the user can create private projects", () ->
        user = Immutable.fromJS({
            id: 1,
            name: "fake1",
            max_private_projects: 10,
            total_private_projects: 1,
            max_memberships_private_projects: 20
        })

        currentUserService._user = user

        result = currentUserService.canCreatePrivateProjects(10)

        expect(result).to.be.eql({
            valid: true
        })

    it "the user can't create public projects if they reach the maximum number of private projects", () ->
        user = Immutable.fromJS({
            id: 1,
            name: "fake1",
            max_public_projects: 1,
            total_public_projects: 1
        })

        currentUserService._user = user

        result = currentUserService.canCreatePublicProjects(0)

        expect(result).to.be.eql({
            valid: false,
            reason: 'max_public_projects',
            type: 'public_project',
            current: 1,
            max: 1
        })

    it "the user can create public projects", () ->
        user = Immutable.fromJS({
            id: 1,
            name: "fake1",
            max_public_projects: 10,
            total_public_projects: 1,
            max_memberships_public_projects: 20
        })

        currentUserService._user = user

        result = currentUserService.canCreatePublicProjects(10)

        expect(result).to.be.eql({
            valid: true
        })

    it "the user can own public project", () ->
        user = Immutable.fromJS({
            id: 1,
            name: "fake1",
            max_public_projects: 10,
            total_public_projects: 1,
            max_memberships_public_projects: 20
        })

        currentUserService._user = user

        project = Immutable.fromJS({
                id: 2,
                name: "fake2",
                total_memberships: 5,
                is_private: false
        })

        result = currentUserService.canOwnProject(project)

        expect(result).to.be.eql({
            valid: true
        })

    it "the user can't own public project because of max projects", () ->
        user = Immutable.fromJS({
            id: 1,
            name: "fake1",
            max_public_projects: 1,
            total_public_projects: 1,
            max_memberships_public_projects: 20
        })

        currentUserService._user = user

        project = Immutable.fromJS({
                id: 2,
                name: "fake2",
                total_memberships: 5,
                is_private: false
        })

        result = currentUserService.canOwnProject(project)

        expect(result).to.be.eql({
            valid: false
            reason: 'max_public_projects'
            type: 'public_project',
            current: 1,
            max: 1
        })


    it "the user can't own public project because of max memberships", () ->
        user = Immutable.fromJS({
            id: 1,
            name: "fake1",
            max_public_projects: 5,
            total_public_projects: 1,
            max_memberships_public_projects: 4
        })

        currentUserService._user = user

        project = Immutable.fromJS({
                id: 2,
                name: "fake2",
                total_memberships: 5,
                is_private: false
        })

        result = currentUserService.canOwnProject(project)

        expect(result).to.be.eql({
            valid: false
            reason: 'max_members_public_projects'
            type: 'public_project',
            current: 5,
            max: 4
        })

    it "the user can own private project", () ->
        user = Immutable.fromJS({
            id: 1,
            name: "fake1",
            max_private_projects: 10,
            total_private_projects: 1,
            max_memberships_private_projects: 20
        })

        currentUserService._user = user

        project = Immutable.fromJS({
                id: 2,
                name: "fake2",
                total_memberships: 5,
                is_private: true
        })

        result = currentUserService.canOwnProject(project)

        expect(result).to.be.eql({
            valid: true
        })

    it "the user can't own private project because of max projects", () ->
        user = Immutable.fromJS({
            id: 1,
            name: "fake1",
            max_private_projects: 1,
            total_private_projects: 1,
            max_memberships_private_projects: 20
        })

        currentUserService._user = user

        project = Immutable.fromJS({
                id: 2,
                name: "fake2",
                total_memberships: 5,
                is_private: true
        })

        result = currentUserService.canOwnProject(project)

        expect(result).to.be.eql({
            valid: false
            reason: 'max_private_projects'
            type: 'private_project',
            current: 1,
            max: 1
        })


    it "the user can't own private project because of max memberships", () ->
        user = Immutable.fromJS({
            id: 1,
            name: "fake1",
            max_private_projects: 10,
            total_private_projects: 1,
            max_memberships_private_projects: 4
        })

        currentUserService._user = user

        project = Immutable.fromJS({
                id: 2,
                name: "fake2",
                total_memberships: 5,
                is_private: true
        })

        result = currentUserService.canOwnProject(project)

        expect(result).to.be.eql({
            valid: false
            reason: 'max_members_private_projects'
            type: 'private_project',
            current: 5,
            max: 4
        })
