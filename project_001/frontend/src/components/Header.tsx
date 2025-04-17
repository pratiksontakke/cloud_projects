
import React from "react";
import { Cloud, Server } from "lucide-react";

const Header = () => {
  return (
    <header className="header-gradient px-6 py-4 shadow-md">
      <div className="container mx-auto">
        <div className="flex flex-col md:flex-row items-center md:items-start md:justify-between">
          <div>
            <h1 className="text-2xl md:text-3xl font-bold flex items-center">
              <Cloud className="mr-2 h-8 w-8" />
              Tutorials Management Dashboard
            </h1>
            <p className="text-white/80 mt-1">
              Cloud-Ready Frontend for Your Express API
            </p>
          </div>
          
          <div className="mt-4 md:mt-0 bg-white/10 backdrop-blur-sm rounded-lg px-4 py-2 shadow-sm">
            <p className="text-sm font-medium">
              <Server className="inline-block mr-1 h-4 w-4" /> 
              Cloud Deployment Ready
            </p>
            <div className="flex gap-2 mt-1">
              <span className="bg-scientific-purple/80 text-white text-xs px-2 py-0.5 rounded">AWS</span>
              <span className="bg-scientific-blue/80 text-white text-xs px-2 py-0.5 rounded">Azure</span>
              <span className="bg-scientific-teal/80 text-white text-xs px-2 py-0.5 rounded">GCP</span>
            </div>
          </div>
        </div>
      </div>
    </header>
  );
};

export default Header;
