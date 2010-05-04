#!/usr/bin/python
import koji
import os

_known_packages = [f for f in os.listdir('/home/devel/jesusr/dev/MySpecs/rel-eng/packages/') if f != ".readme"]

def filter_cp_tags(tag):
    return tag['name'].endswith('-cp-0.1-candidate')

if __name__ == "__main__":
    session = koji.ClientSession('http://koji.rhndev.redhat.com/kojihub')
    session.ssl_login('/home/devel/jesusr/.spacewalk.cert', '/home/devel/jesusr/.spacewalk-ca.cert', '/home/devel/jesusr/.spacewalk-ca.cert')
    cptags = filter(filter_cp_tags, session.listTags())

    for tag in cptags:
        opts = {}
        opts['tagID'] = tag['id']
        pkgsintag = session.listPackages(**opts)
        tagset = set([p['package_name'] for p in pkgsintag])
        knownset = set(_known_packages)
        neededset = knownset - tagset
        for pkgtoadd in neededset:
            print "tag(%s) needs package(%s)" %(tag['name'],pkgtoadd)
            session.packageListAdd(tag['name'],pkgtoadd,'jesusr',force=False, block=False) 
